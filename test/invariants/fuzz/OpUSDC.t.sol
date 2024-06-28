// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {SetupOpUSDC} from './SetupOpUSDC.sol';
import {IL1OpUSDCBridgeAdapter} from 'interfaces/IL1OpUSDCBridgeAdapter.sol';

//solhint-disable custom-errors
contract OpUsdcTest is SetupOpUSDC {
  /////////////////////////////////////////////////////////////////////
  //                         Ghost variables                         //
  /////////////////////////////////////////////////////////////////////

  uint256 internal _L1PreviousUserNonce;
  uint256 internal _L1CurrentUserNonce;
  address internal _xdomSenderDuringCall; // Who called a previous function (amongst the agents)

  /////////////////////////////////////////////////////////////////////
  //                           Properties                            //
  /////////////////////////////////////////////////////////////////////

  // debug: echidna debug setup
  function fuzz_testDeployments() public {
    assert(l2Adapter.LINKED_ADAPTER() == address(l1Adapter));
    assert(l2Adapter.MESSENGER() == address(mockMessenger));
    assert(l2Adapter.USDC() == address(usdcBridged));

    assert(l1Adapter.LINKED_ADAPTER() == address(l2Adapter));
    assert(l1Adapter.MESSENGER() == address(mockMessenger));
    assert(l1Adapter.USDC() == address(usdcMainnet));
  }

  // todo: craft valid signature for the overloaded send mnessage
  // New messages should not be sent if the state is not active 1
  function fuzz_noMessageIfNotActiveL1(address _to, uint256 _amount, uint32 _minGasLimit) public AgentOrDeployer {
    // Precondition
    // todo: clean this mess
    // todo: modifiers for balance of and mint/approval

    // Insure we're using the correct xdom sender (for the receiving end/linked l2)
    require(mockMessenger.xDomainMessageSender() == address(l1Adapter));

    // Avoid balance overflow
    require(usdcMainnet.balanceOf(_to) < 2 ** 255 - 1 - _amount);
    require(usdcBridged.balanceOf(_to) < 2 ** 255 - 1 - _amount);
    require(usdcMainnet.balanceOf(address(l1Adapter)) < 2 ** 255 - 1 - _amount);

    // usdc init v2 black list usdc address itself
    require(_to != address(0) && _to != address(usdcMainnet) && _to != address(usdcBridged));

    // provided enough usdc on l1
    require(_amount > 0);
    hevm.prank(_usdcMinter);
    usdcMainnet.mint(currentCaller, _amount);

    hevm.prank(currentCaller);
    usdcMainnet.approve(address(l1Adapter), _amount);

    uint256 _toBalanceBefore = usdcBridged.balanceOf(_to);
    uint256 _fromBalanceBefore = usdcMainnet.balanceOf(currentCaller);

    hevm.prank(currentCaller);

    // Action
    try l1Adapter.sendMessage(_to, _amount, _minGasLimit) {
      // Postcondition
      assert(l1Adapter.messengerStatus() == IL1OpUSDCBridgeAdapter.Status.Active);
      assert(usdcBridged.balanceOf(_to) == _toBalanceBefore + _amount);
      assert(usdcMainnet.balanceOf(currentCaller) == _fromBalanceBefore - _amount);
    } catch {
      // fails either because of wrong xdom msg sender or because of the status, but xdom sender is constrained in precond
      assert(l1Adapter.messengerStatus() != IL1OpUSDCBridgeAdapter.Status.Active);
      assert(usdcBridged.balanceOf(_to) == _toBalanceBefore);
      assert(usdcMainnet.balanceOf(currentCaller) == _fromBalanceBefore);
    }
  }

  // todo: craft valid signature for the overloaded send mnessage
  // New messages should not be sent if the state is not active 1
  // User who bridges tokens should receive them on the destination chain 2
  // Amount locked on L1 == amount minted on L2 3
  function fuzz_noMessageIfNotActiveL2(address _to, uint256 _amount, uint32 _minGasLimit) public AgentOrDeployer {
    // Insure we're using the correct xdom sender (for the receiving end/linked l1)
    // require(mockMessenger.xDomainMessageSender() == address(l2Adapter));

    // Avoid balance overflow
    require(usdcMainnet.balanceOf(_to) < 2 ** 255 - 1 - _amount);
    require(usdcBridged.balanceOf(_to) < 2 ** 255 - 1 - _amount);

    // usdc init v2 black list usdc address itself
    require(!(_to == address(0) || _to == address(usdcBridged)));

    // provided enough usdc on l1
    require(_amount > 0);
    require(usdcBridged.balanceOf(currentCaller) >= _amount);

    hevm.prank(currentCaller);
    usdcBridged.approve(address(l2Adapter), _amount);

    uint256 _fromBalanceBefore = usdcBridged.balanceOf(currentCaller);
    uint256 _toBalanceBefore = usdcMainnet.balanceOf(_to);

    hevm.prank(currentCaller);

    // Action
    try l2Adapter.sendMessage(_to, _amount, _minGasLimit) {
      // Postcondition

      // Correct xdomain sender?
      assert(mockMessenger.xDomainMessageSender() == address(l2Adapter));

      // 1
      assert(!l2Adapter.isMessagingDisabled());

      // 2
      assert(usdcBridged.balanceOf(currentCaller) == _fromBalanceBefore - _amount);
      assert(usdcMainnet.balanceOf(_to) == _toBalanceBefore + _amount);

      // 3
      assert(usdcMainnet.balanceOf(address(l1Adapter)) == usdcBridged.totalSupply());
    } catch {
      // 1
      assert(l2Adapter.isMessagingDisabled());

      // 2
      assert(usdcBridged.balanceOf(currentCaller) == _fromBalanceBefore);
      assert(usdcMainnet.balanceOf(_to) == _toBalanceBefore);
    }
  }

  // Both adapters state should match 4
  function fuzz_assertAdapterStateCongruency() public {
    // Precondition

    // TODO: L2 can be still active if L1 is upgragding or paused (bridged msg reverting)
    // TODO: fix to rather check with potential pending msg + include a way to mock bridge sometimes failing on message transfer

    // Postcondition
    // 4
    assert(
      l1Adapter.messengerStatus() != IL1OpUSDCBridgeAdapter.Status.Active
        ? l2Adapter.isMessagingDisabled()
        : !l2Adapter.isMessagingDisabled()
    );
  }

  // user nonce should be monotonically increasing  5
  function fuzz_L1NonceIncremental() public {
    if (_L1CurrentUserNonce == 0) {
      assert(l1Adapter.userNonce(currentCaller) == 0);
    } else {
      assert(_L1PreviousUserNonce == _L1CurrentUserNonce - 1);
    }
  }

  // Locked USDC on L1adapter should be able to be burned only if L1 adapter is deprecated
  function fuzz_BurnLockedUSDC() public {
    // Enable l1 adapter to burn locked usdc
    hevm.prank(usdcMainnet.masterMinter());
    usdcMainnet.configureMinter(address(l1Adapter), type(uint256).max);

    hevm.prank(l1Adapter.newOwner());
    // 6
    try l1Adapter.burnLockedUSDC() {
      assert(l1Adapter.messengerStatus() == IL1OpUSDCBridgeAdapter.Status.Deprecated);
      assert(usdcMainnet.balanceOf(address(l1Adapter)) == 0);
    } catch {
      assert(l1Adapter.messengerStatus() != IL1OpUSDCBridgeAdapter.Status.Deprecated);
    }
  }

  // Status pause should be able to be set only by the owner and through the correct function
  function fuzz_PauseMessaging(uint32 _minGasLimit) public AgentOrDeployer {
    // Precondition
    IL1OpUSDCBridgeAdapter.Status _previousL1Status = l1Adapter.messengerStatus();
    bool _previousL2Status = l2Adapter.isMessagingDisabled();

    hevm.prank(currentCaller);
    // Action
    // 7
    try l1Adapter.stopMessaging(_minGasLimit) {
      // Post condition
      assert(currentCaller == l1Adapter.owner());
      assert(_previousL1Status == IL1OpUSDCBridgeAdapter.Status.Active);
      assert(!_previousL2Status);
      assert(l1Adapter.messengerStatus() == IL1OpUSDCBridgeAdapter.Status.Paused);
      assert(l2Adapter.isMessagingDisabled());
    } catch {
      assert(
        l1Adapter.messengerStatus() != IL1OpUSDCBridgeAdapter.Status.Active || currentCaller != l1Adapter.owner()
          || _previousL2Status
      );
    }
  }

  // Resume should be able to be set only by the owner and through the correct function
  function fuzz_ResumeMessaging(uint32 _minGasLimit) public AgentOrDeployer {
    IL1OpUSDCBridgeAdapter.Status _previousL1Status = l1Adapter.messengerStatus();
    bool _previousL2Status = l2Adapter.isMessagingDisabled();

    hevm.prank(currentCaller);
    // 8
    try l1Adapter.resumeMessaging(_minGasLimit) {
      assert(currentCaller == l1Adapter.owner());
      assert(_previousL1Status == IL1OpUSDCBridgeAdapter.Status.Paused);
      assert(_previousL2Status);
      assert(l1Adapter.messengerStatus() == IL1OpUSDCBridgeAdapter.Status.Active);
      assert(!l2Adapter.isMessagingDisabled());
    } catch {
      assert(
        l1Adapter.messengerStatus() != IL1OpUSDCBridgeAdapter.Status.Paused || currentCaller != l1Adapter.owner()
          || !_previousL2Status
      );
    }
  }

  /////////////////////////////////////////////////////////////////////
  //                Expose target contract selectors                 //
  /////////////////////////////////////////////////////////////////////

  // Expose all selectors from the adapter, pranked and with ghost variables if needed
  // Caller is one of the agents (incl the deployer/initial owner)
  function generateCallAdapterL1(
    uint256 _selectorIndex,
    address _addressA,
    address _addressB,
    uint256 _uintA,
    uint256 _uintB,
    bytes calldata _bytesA,
    uint32 _uint32A,
    uint32 _uint32B
  ) public AgentOrDeployer {
    _selectorIndex = _selectorIndex % 8;

    hevm.prank(currentCaller);

    if (_selectorIndex == 0) {
      // Do not revert on the transferFrom call
      require(_uintA > 0);
      require(usdcMainnet.balanceOf(currentCaller) < 2 ** 255 - 1 - _uintA);
      hevm.prank(_usdcMinter);
      usdcMainnet.mint(currentCaller, _uintA);

      hevm.prank(currentCaller);
      usdcMainnet.approve(address(l1Adapter), _uintA);

      // Do not make assumption on nonce logic here, just collect them
      uint256 _initialNonce = l1Adapter.userNonce(currentCaller);

      hevm.prank(currentCaller);
      try l1Adapter.sendMessage(_addressA, _uintA, _uint32A) {
        _L1PreviousUserNonce = _initialNonce;
        _L1CurrentUserNonce = l1Adapter.userNonce(currentCaller);
      } catch {}
    } else if (_selectorIndex == 1) {
      try l1Adapter.sendMessage(_addressA, _addressB, _uintA, _bytesA, _uintB, _uint32A) {} catch {}
    } else if (_selectorIndex == 2) {
      try l1Adapter.receiveMessage(_addressA, _uintA) {} catch {}
    } else if (_selectorIndex == 3) {
      try l1Adapter.migrateToNative(_addressA, _uint32A, _uint32B) {} catch {}
    } else if (_selectorIndex == 4) {
      try l1Adapter.setBurnAmount(_uintA) {} catch {}
    } else if (_selectorIndex == 5) {
      try l1Adapter.burnLockedUSDC() {} catch {}
    } else if (_selectorIndex == 6) {
      try l1Adapter.stopMessaging(_uint32A) {} catch {}
    } else {
      try l1Adapter.resumeMessaging(_uint32A) {} catch {}
    }
  }

  function generateCallAdapterL2(
    uint256 _selectorIndex,
    address _addressA,
    address _addressB,
    uint256 _uintA,
    uint256 _uintB,
    bytes calldata _bytesA,
    uint32 _uint32A
  ) public AgentOrDeployer {
    _selectorIndex = _selectorIndex % 7;

    hevm.prank(currentCaller);

    if (_selectorIndex == 0) {
      try l2Adapter.sendMessage(_addressA, _uintA, _uint32A) {} catch {}
    } else if (_selectorIndex == 1) {
      try l2Adapter.sendMessage(_addressA, _addressB, _uintA, _bytesA, _uintB, _uint32A) {} catch {}
    } else if (_selectorIndex == 2) {
      try l2Adapter.receiveMessage(_addressA, _uintA) {} catch {}
    } else if (_selectorIndex == 3) {
      try l2Adapter.receiveMigrateToNative(_addressA, _uint32A) {} catch {}
    } else if (_selectorIndex == 4) {
      try l2Adapter.receiveStopMessaging() {} catch {}
    } else if (_selectorIndex == 5) {
      try l2Adapter.receiveResumeMessaging() {} catch {}
    } else {
      try l2Adapter.callUsdcTransaction(_bytesA) {} catch {}
    }
  }

  // Send a call to the L1 or L2 adapter (simulating a direct interaction with the bridge to send the crosschain msg)
  function generateMessageToL1(
    uint256 _selectorIndex,
    address _addressA,
    address _addressB,
    uint256 _uintA,
    uint256 _uintB,
    bytes calldata _bytesA,
    uint32 _uint32A,
    uint32 _uint32B
  ) public AgentOrDeployer {
    _selectorIndex = _selectorIndex % 8;
    bytes memory _payload;

    if (_selectorIndex == 0) {
      _payload = abi.encodeWithSignature('sendMessage(address,uint256,uint32)', abi.encode(_addressA, _uintA, _uint32A));
    } else if (_selectorIndex == 1) {
      _payload = abi.encodeWithSignature(
        'sendMessage(address,address,uint256,bytes,uint256,uint32)',
        abi.encode(_addressA, _addressB, _uintA, _bytesA, _uintB, _uint32A)
      );
    } else if (_selectorIndex == 2) {
      _payload = abi.encodeCall(l1Adapter.receiveMessage, (_addressA, _uintA));
    } else if (_selectorIndex == 3) {
      _payload = abi.encodeCall(l1Adapter.migrateToNative, (_addressA, _uint32A, _uint32B));
    } else if (_selectorIndex == 4) {
      _payload = abi.encodeCall(l1Adapter.setBurnAmount, (_uintA));
    } else if (_selectorIndex == 5) {
      _payload = abi.encodeCall(l1Adapter.burnLockedUSDC, ());
    } else if (_selectorIndex == 6) {
      _payload = abi.encodeCall(l1Adapter.stopMessaging, (_uint32A));
    } else {
      _payload = abi.encodeCall(l1Adapter.resumeMessaging, (_uint32A));
    }

    hevm.prank(currentCaller);
    mockMessenger.sendMessage(currentCaller, _payload, _uint32A);
  }

  function generateMessageToL2(
    uint256 _selectorIndex,
    address _addressA,
    address _addressB,
    uint256 _uintA,
    uint256 _uintB,
    bytes calldata _bytesA,
    uint32 _uint32A
  ) public AgentOrDeployer {
    _selectorIndex = _selectorIndex % 7;
    bytes memory _payload;

    if (_selectorIndex == 0) {
      _payload = abi.encodeWithSignature('sendMessage(address,uint256,uint32)', abi.encode(_addressA, _uintA, _uint32A));
    } else if (_selectorIndex == 1) {
      _payload = abi.encodeWithSignature(
        'sendMessage(address,address,uint256,bytes,uint256,uint32)',
        abi.encode(_addressA, _addressB, _uintA, _bytesA, _uintB, _uint32A)
      );
    } else if (_selectorIndex == 2) {
      _payload = abi.encodeCall(l2Adapter.receiveMessage, (_addressA, _uintA));
    } else if (_selectorIndex == 3) {
      _payload = abi.encodeCall(l2Adapter.receiveMigrateToNative, (_addressA, _uint32A));
    } else if (_selectorIndex == 4) {
      _payload = abi.encodeCall(l2Adapter.receiveStopMessaging, ());
    } else if (_selectorIndex == 5) {
      _payload = abi.encodeCall(l2Adapter.receiveResumeMessaging, ());
    } else {
      _payload = abi.encodeCall(l2Adapter.callUsdcTransaction, (_bytesA));
    }

    hevm.prank(currentCaller);
    mockMessenger.sendMessage(currentCaller, _payload, _uint32A);
  }

  function generateCallFactory() public AgentOrDeployer {}
}
