// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {SetupOpUSDC} from './SetupOpUSDC.sol';

import {USDCInitTxs} from 'contracts/utils/USDCInitTxs.sol';
import {IL1OpUSDCBridgeAdapter} from 'interfaces/IL1OpUSDCBridgeAdapter.sol';
import {IL1OpUSDCFactory} from 'interfaces/IL1OpUSDCFactory.sol';
import {USDC_IMPLEMENTATION_CREATION_CODE} from 'script/utils/USDCImplementationCreationCode.sol';

//solhint-disable custom-errors
contract OpUsdcTest is SetupOpUSDC {
  /////////////////////////////////////////////////////////////////////
  //                         Ghost variables                         //
  /////////////////////////////////////////////////////////////////////

  uint256 internal _ghost_L1PreviousUserNonce;
  uint256 internal _ghost_L1CurrentUserNonce;
  bool internal _ghost_hasBeenDeprecatedBefore; // Track if setBurnAmount has been called once before
  mapping(address => bool) internal _ghost_l2AdapterDeployed;
  mapping(address => bool) internal _ghost_l2FactoryDeployed;

  /////////////////////////////////////////////////////////////////////
  //                           Properties                            //
  /////////////////////////////////////////////////////////////////////

  // // debug: echidna debug setup
  // function fuzz_testDeployments() public view {
  //   assert(l2Adapter.LINKED_ADAPTER() == address(l1Adapter));
  //   assert(l2Adapter.MESSENGER() == address(mockMessenger));
  //   assert(l2Adapter.USDC() == address(usdcBridged));

  //   assert(l1Adapter.LINKED_ADAPTER() == address(l2Adapter));
  //   assert(l1Adapter.MESSENGER() == address(mockMessenger));
  //   assert(l1Adapter.USDC() == address(usdcMainnet));
  // }

  // todo: craft valid signature for the overloaded send mnessage
  // New messages should not be sent if the state is not active 1
  function fuzz_noMessageIfNotActiveL1(address _to, uint256 _amount, uint32 _minGasLimit) public agentOrDeployer {
    // Precondition
    // todo: clean this mess
    // todo: modifiers for balance of and mint/approval

    // Insure we're using the correct xdom sender (for the receiving end/linked l2)
    // require(mockMessenger.xDomainMessageSender() == address(l1Adapter));

    // Avoid balance overflow
    require(usdcMainnet.balanceOf(_to) < 2 ** 255 - 1 - _amount);
    require(usdcBridged.balanceOf(_to) < 2 ** 255 - 1 - _amount);
    require(usdcMainnet.balanceOf(address(l1Adapter)) < 2 ** 255 - 1 - _amount);

    // usdc init v2 black list usdc address itself
    require(_to != address(0) && _to != address(usdcMainnet) && _to != address(usdcBridged));

    // provided enough usdc on l1
    require(_amount > 0);
    hevm.prank(_usdcMinter);
    usdcMainnet.mint(_currentCaller, _amount);

    hevm.prank(_currentCaller);
    usdcMainnet.approve(address(l1Adapter), _amount);

    uint256 _fromBalanceBefore = usdcMainnet.balanceOf(_currentCaller);

    hevm.prank(_currentCaller);
    // Action
    try l1Adapter.sendMessage(_to, _amount, _minGasLimit) {
      // Postcondition
      assert(l1Adapter.messengerStatus() == IL1OpUSDCBridgeAdapter.Status.Active);
      // assert(usdcBridged.balanceOf(_to) == _toBalanceBefore + _amount);
      assert(usdcMainnet.balanceOf(_currentCaller) == _fromBalanceBefore - _amount);
    } catch {
      // fails either because of wrong xdom msg sender or because of the status, but xdom sender is constrained in precond
      assert(l1Adapter.messengerStatus() != IL1OpUSDCBridgeAdapter.Status.Active);
      // assert(usdcBridged.balanceOf(_to) == _toBalanceBefore);
      assert(usdcMainnet.balanceOf(_currentCaller) == _fromBalanceBefore);
    }
  }

  // User who bridges tokens should receive them on the destination chain      2
  function fuzz_receiveL2Token(bytes calldata message) public view {
    // Precondition
    // There is a pending message to be executed
    require(mockMessenger.isInQueue(address(l2Adapter), message, address(l1Adapter)));
  }

  // todo: craft valid signature for the overloaded send mnessage
  // New messages should not be sent if the state is not active 1
  // User who bridges tokens should receive them on the destination chain 2
  // Amount locked on L1 == amount minted on L2 3
  function fuzz_noMessageIfNotActiveL2(address _to, uint256 _amount, uint32 _minGasLimit) public agentOrDeployer {
    // Avoid balance overflow
    require(usdcMainnet.balanceOf(_to) < 2 ** 255 - 1 - _amount);
    require(usdcBridged.balanceOf(_to) < 2 ** 255 - 1 - _amount);

    // usdc init v2 black list usdc address itself
    require(!(_to == address(0) || _to == address(usdcBridged)));

    // provided enough usdc on l1
    require(_amount > 0);
    require(usdcBridged.balanceOf(_currentCaller) >= _amount);

    hevm.prank(_currentCaller);
    usdcBridged.approve(address(l2Adapter), _amount);

    uint256 _fromBalanceBefore = usdcBridged.balanceOf(_currentCaller);
    uint256 _toBalanceBefore = usdcMainnet.balanceOf(_to);

    hevm.prank(_currentCaller);

    // Action
    try l2Adapter.sendMessage(_to, _amount, _minGasLimit) {
      // Postcondition

      // Correct xdomain sender?
      assert(mockMessenger.xDomainMessageSender() == address(l2Adapter));

      // 1
      assert(!l2Adapter.isMessagingDisabled());

      // 2
      assert(usdcBridged.balanceOf(_currentCaller) == _fromBalanceBefore - _amount);
      assert(usdcMainnet.balanceOf(_to) == _toBalanceBefore + _amount);

      // 3
      assert(usdcMainnet.balanceOf(address(l1Adapter)) == usdcBridged.totalSupply());
    } catch {
      // 1
      assert(l2Adapter.isMessagingDisabled());

      // 2
      assert(usdcBridged.balanceOf(_currentCaller) == _fromBalanceBefore);
      assert(usdcMainnet.balanceOf(_to) == _toBalanceBefore);
    }
  }

  // Both adapters state should match 4
  function fuzz_assertAdapterStateCongruency() public view {
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
  function fuzz_L1NonceIncremental() public view {
    if (_ghost_L1CurrentUserNonce == 0) {
      assert(l1Adapter.userNonce(_currentCaller) == 0);
    } else {
      assert(_ghost_L1PreviousUserNonce == _ghost_L1CurrentUserNonce - 1);
    }
  }

  // Locked USDC on L1adapter should be able to be burned only if L1 adapter is deprecated
  function fuzz_BurnLockedUSDC() public {
    // Enable l1 adapter to burn locked usdc
    hevm.prank(usdcMainnet.masterMinter());
    usdcMainnet.configureMinter(address(l1Adapter), type(uint256).max);

    require(l1Adapter.messengerStatus() == IL1OpUSDCBridgeAdapter.Status.Upgrading);

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
  function fuzz_PauseMessaging(uint32 _minGasLimit) public agentOrDeployer {
    // Precondition
    IL1OpUSDCBridgeAdapter.Status _previousL1Status = l1Adapter.messengerStatus();

    hevm.prank(_currentCaller);
    // Action
    // 7
    try l1Adapter.stopMessaging(_minGasLimit) {
      // Post condition
      assert(_currentCaller == l1Adapter.owner());
      assert(
        _previousL1Status == IL1OpUSDCBridgeAdapter.Status.Active
          || _previousL1Status == IL1OpUSDCBridgeAdapter.Status.Paused
      );
      assert(l1Adapter.messengerStatus() == IL1OpUSDCBridgeAdapter.Status.Paused);
      // TODO: check the stop messaging on l2 was succesful too
      //assert(l2Adapter.isMessagingDisabled());
    } catch {
      assert(
        l1Adapter.messengerStatus() != IL1OpUSDCBridgeAdapter.Status.Active
          || l1Adapter.messengerStatus() != IL1OpUSDCBridgeAdapter.Status.Paused || _currentCaller != l1Adapter.owner()
      );
    }
  }

  // Resume should be able to be set only by the owner and through the correct function
  function fuzz_ResumeMessaging(uint32 _minGasLimit) public agentOrDeployer {
    IL1OpUSDCBridgeAdapter.Status _previousL1Status = l1Adapter.messengerStatus();

    hevm.prank(_currentCaller);
    // 8
    try l1Adapter.resumeMessaging(_minGasLimit) {
      assert(_currentCaller == l1Adapter.owner());
      assert(
        _previousL1Status == IL1OpUSDCBridgeAdapter.Status.Active
          || _previousL1Status == IL1OpUSDCBridgeAdapter.Status.Paused
      );
      assert(l1Adapter.messengerStatus() == IL1OpUSDCBridgeAdapter.Status.Active);
      // TODO: check the stop messaging on l2 was succesful too
      //assert(!l2Adapter.isMessagingDisabled());
    } catch {
      assert(
        l1Adapter.messengerStatus() != IL1OpUSDCBridgeAdapter.Status.Active
          || l1Adapter.messengerStatus() != IL1OpUSDCBridgeAdapter.Status.Paused || _currentCaller != l1Adapter.owner()
      );
    }
  }

  // todo: fix (try never succeed?) - first try again with more runs (needs to msg l2, then msg back l1)
  // Set burn only if migrating  9
  function fuzz_setBurnAmount() public {
    // Precondition
    uint256 _previousBurnAmount = l1Adapter.burnAmount();
    uint256 _l2totalSupply = usdcBridged.totalSupply();
    IL1OpUSDCBridgeAdapter.Status _previousState = l1Adapter.messengerStatus();

    // Ensure the message is in the queue, to the l1adapter, from the l2 adapter
    require(
      mockMessenger.isInQueue(
        address(l1Adapter), abi.encodeWithSignature('setBurnAmount(uint256)', _l2totalSupply), address(l2Adapter)
      )
    );

    hevm.prank(l1Adapter.MESSENGER());
    // Action
    // 9
    try l1Adapter.setBurnAmount(_l2totalSupply) {
      //Precontion
      assert(_previousState == IL1OpUSDCBridgeAdapter.Status.Upgrading);
      // Postcondition
      assert(l1Adapter.messengerStatus() == IL1OpUSDCBridgeAdapter.Status.Deprecated);
      assert(l1Adapter.burnAmount() == _l2totalSupply);
      _ghost_hasBeenDeprecatedBefore = true;
    } catch {
      assert(l1Adapter.burnAmount() == _previousBurnAmount);
    }
  }

  ///Deprecated state should be irreversible  10
  function fuzz_deprecatedIrreversible() public {
    // If the l1 adapter has been deprecated once before, it cannot have any other status ever again
    if (_ghost_hasBeenDeprecatedBefore) assert(l1Adapter.messengerStatus() == IL1OpUSDCBridgeAdapter.Status.Deprecated);
  }

  // Upgrading state only via migrate to native, should be callable multiple times (msg fails)
  function fuzz_migrateToNativeMultipleCall() public {
    // Precondition
    // Insure we haven't started the migration or we only initiated/is pending in the bridge
    require(
      l1Adapter.messengerStatus() == IL1OpUSDCBridgeAdapter.Status.Active
        || l1Adapter.messengerStatus() == IL1OpUSDCBridgeAdapter.Status.Upgrading
    );

    // Action
    // 11
    try l1Adapter.migrateToNative(_currentCaller, 0, 0) {
      assert(l1Adapter.messengerStatus() == IL1OpUSDCBridgeAdapter.Status.Upgrading);
    } catch {}

    // try calling a second time
    try l1Adapter.migrateToNative(_currentCaller, 0, 0) {}
    catch {
      assert(false);
    }

    // Postcondition
    assert(l1Adapter.messengerStatus() == IL1OpUSDCBridgeAdapter.Status.Upgrading);
  }

  // All in flight transactions should successfully settle after a migration to native usdc 12
  // we leverage the mock bridge queue (fifo)
  function fuzz_noDropPendingTxWhenMigration() public {
    // preconditions

    // action

    // add to bridge queue
    // send msg to l1 [USDC to l1]
    // send msg to l2  [USDC to l1, USDC to l2]
    // migration [USDC to l1, USDC to l2, receiveMigrateToNative]

    // execute: [USDC to l1, USDC to l2, receiveMigrateToNative] then [USDC to l2, receiveMigrateToNative] then [receiveMigrateToNative] then [setBurnAmount]

    // add to queue
    // send msg to l1 [setBurnAmount, USDC to l1]
    // send msg to l2 [setBurnAmount, USDC to l1, USDC to l2]

    // execute [setBurnAmount, USDC to l1, USDC to l2] then [USDC to l1, USDC to l2] then [USDC to l2]

    // postconditions
    // balance are correct
    // sending msg is now paused
  }

  // todo: add adapters to agents? Force calling from the adapter?
  // Bridged USDC Proxy should only be upgradeable through the L2 Adapter  13
  function fuzz_proxyUpgradeOnlyThroughL2() public agentOrDeployer {
    // Precondition

    // Action
    // 13
  }

  // | Incoming successful messages should only come from the linked adapter's                                     | High level          | 14    | [ ]  | [ ]  |

  // Any chain should be able to have as many protocols deployed without the factory blocking deployments 15
  // Protocols deployed on one L2 should never have a matching address with a protocol on a different L2 16
  function fuzz_factoryNeverFailsToDeploy() public agentOrDeployer {
    bytes[] memory usdcInitTxns = new bytes[](3);
    usdcInitTxns[0] = USDCInitTxs.INITIALIZEV2;
    usdcInitTxns[1] = USDCInitTxs.INITIALIZEV2_1;
    usdcInitTxns[2] = USDCInitTxs.INITIALIZEV2_2;

    IL1OpUSDCFactory.L2Deployments memory _l2Deployments =
      IL1OpUSDCFactory.L2Deployments(address(this), USDC_IMPLEMENTATION_CREATION_CODE, usdcInitTxns, 3_000_000);

    try factory.deploy(address(mockMessenger), _currentCaller, _l2Deployments) returns (
      address, address _l2Factory, address _l2Adapter
    ) {
      // Postcondition
      // 15
      // Deployment msg is in the bridge queue

      // l1 adapter deployed

      // 16 - no matching address on different L2
      assert(!_ghost_l2AdapterDeployed[_l2Adapter]);
      assert(!_ghost_l2FactoryDeployed[_l2Factory]);

      _ghost_l2AdapterDeployed[_l2Adapter] = true;
      _ghost_l2FactoryDeployed[_l2Factory] = true;
    } catch {}
  }

  // USDC proxy admin and token ownership rights can only be transferred during the migration to native flow  17
  function fuzz_onlyMigrateToNativeForOwnershipTransfer() public {
    // Precondition
    // Action
    // Postcondition
    // 17
  }

  // Status should either be active, paused, upgrading or deprecated
  function fuzz_correctStatus() public {
    assert(
      l1Adapter.messengerStatus() == IL1OpUSDCBridgeAdapter.Status.Active
        || l1Adapter.messengerStatus() == IL1OpUSDCBridgeAdapter.Status.Paused
        || l1Adapter.messengerStatus() == IL1OpUSDCBridgeAdapter.Status.Upgrading
        || l1Adapter.messengerStatus() == IL1OpUSDCBridgeAdapter.Status.Deprecated
    );
  }

  /////////////////////////////////////////////////////////////////////
  //                         Bridge mocking                          //
  /////////////////////////////////////////////////////////////////////

  function executeMessage() public {
    mockMessenger.executeMessage();
  }

  /////////////////////////////////////////////////////////////////////
  //                Expose target contract selectors                 //
  /////////////////////////////////////////////////////////////////////

  // Expose all selectors from the adapter, pranked and with ghost variables if needed
  // Caller is one of the _agents (incl the deployer/initial owner)
  function generateCallAdapterL1(
    uint256 _selectorIndex,
    address _addressA,
    address _addressB,
    uint256 _uintA,
    uint256 _uintB,
    bytes calldata _bytesA,
    uint32 _uint32A,
    uint32 _uint32B
  ) public agentOrDeployer {
    _selectorIndex = _selectorIndex % 8;

    hevm.prank(_currentCaller);

    if (_selectorIndex == 0) {
      // Do not revert on the transferFrom call
      require(_uintA > 0);
      require(usdcMainnet.balanceOf(_currentCaller) < 2 ** 255 - 1 - _uintA);
      hevm.prank(_usdcMinter);
      usdcMainnet.mint(_currentCaller, _uintA);

      hevm.prank(_currentCaller);
      usdcMainnet.approve(address(l1Adapter), _uintA);

      // Do not make assumption on nonce logic here, just collect them
      uint256 _initialNonce = l1Adapter.userNonce(_currentCaller);

      hevm.prank(_currentCaller);
      try l1Adapter.sendMessage(_addressA, _uintA, _uint32A) {
        _ghost_L1PreviousUserNonce = _initialNonce;
        _ghost_L1CurrentUserNonce = l1Adapter.userNonce(_currentCaller);
      } catch {}
    } else if (_selectorIndex == 1) {
      try l1Adapter.sendMessage(_addressA, _addressB, _uintA, _bytesA, _uintB, _uint32A) {} catch {}
    } else if (_selectorIndex == 2) {
      try l1Adapter.receiveMessage(_addressA, _uintA) {} catch {}
    } else if (_selectorIndex == 3) {
      try l1Adapter.migrateToNative(_addressA, _uint32A, _uint32B) {} catch {}
    } else if (_selectorIndex == 4) {
      try l1Adapter.setBurnAmount(_uintA) {
        // This will deprecate the adapter
        _ghost_hasBeenDeprecatedBefore = true;
      } catch {}
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
  ) public agentOrDeployer {
    _selectorIndex = _selectorIndex % 7;

    hevm.prank(_currentCaller);

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
  ) public agentOrDeployer {
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

    hevm.prank(_currentCaller);
    mockMessenger.sendMessage(_currentCaller, _payload, _uint32A);
  }

  function generateMessageToL2(
    uint256 _selectorIndex,
    address _addressA,
    address _addressB,
    uint256 _uintA,
    uint256 _uintB,
    bytes calldata _bytesA,
    uint32 _uint32A
  ) public agentOrDeployer {
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

    hevm.prank(_currentCaller);
    mockMessenger.sendMessage(_currentCaller, _payload, _uint32A);
  }

  function generateCallFactory() public agentOrDeployer {}

  function generateCallUSDCL1() public agentOrDeployer {}

  function generateCallUSDCL2() public agentOrDeployer {}

  function generateMessageUSDCL1() public agentOrDeployer {}

  function generateMessageUSDCL2() public agentOrDeployer {}
}
