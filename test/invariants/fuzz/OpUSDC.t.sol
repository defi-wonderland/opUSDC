// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {EchidnaTest} from '../AdvancedTestsUtils.sol';
// https://github.com/crytic/building-secure-contracts/blob/master/program-analysis/echidna/advanced/testing-bytecode.mdq
import {L1OpUSDCBridgeAdapter} from 'contracts/L1OpUSDCBridgeAdapter.sol';
import {IL1OpUSDCFactory, L1OpUSDCFactory} from 'contracts/L1OpUSDCFactory.sol';
import {L2OpUSDCBridgeAdapter} from 'contracts/L2OpUSDCBridgeAdapter.sol';
import {L2OpUSDCFactory} from 'contracts/L2OpUSDCFactory.sol';
import {USDCInitTxs} from 'contracts/utils/USDCInitTxs.sol';
import {IL1OpUSDCBridgeAdapter} from 'interfaces/IL1OpUSDCBridgeAdapter.sol';
import {IL2OpUSDCFactory} from 'interfaces/IL2OpUSDCFactory.sol';
import {IOpUSDCBridgeAdapter} from 'interfaces/IOpUSDCBridgeAdapter.sol';
import {IUSDC} from 'interfaces/external/IUSDC.sol';
import {USDC_IMPLEMENTATION_CREATION_CODE} from 'script/utils/USDCImplementationCreationCode.sol';
import {ITestCrossDomainMessenger} from 'test/utils/interfaces/ITestCrossDomainMessenger.sol';

//solhint-disable custom-errors
contract OpUsdcTest is EchidnaTest {
  IUSDC usdcMainnet;
  IUSDC usdcBridged;

  L1OpUSDCBridgeAdapter public l1Adapter;
  L1OpUSDCFactory public factory;

  L2OpUSDCBridgeAdapter public l2Adapter;
  L2OpUSDCFactory public l2Factory;

  MockBridge public mockMessenger;
  Create2Deployer public create2Deployer;
  address internal _usdcMinter = address(bytes20(uint160(uint256(keccak256('usdc.minter')))));

  constructor() {
    IL1OpUSDCFactory.L2Deployments memory _l2Deployments = _mainnetSetup();
    _l2Setup(_l2Deployments);
    _setupMockBridge();
    _setupUsdc();
  }

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
  //New messages should not be sent if the state is not active | Unit test |
  function fuzz_noMessageIfNotActiveL1(address _to, uint256 _amount, uint32 _minGasLimit) public AgentOrDeployer {
    // Precondition
    // todo: clean this mess
    // todo: modifiers for balance of and mint/approval

    // Insure we're using the correct xdom sender
    require(mockMessenger.xDomainMessageSender() == address(l1Adapter));

    // Avoid balance overflow
    require(usdcMainnet.balanceOf(_to) < 2 ** 255 - 1 - _amount);
    require(usdcBridged.balanceOf(_to) < 2 ** 255 - 1 - _amount);

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

  // todo: insure we can switch it to inactive...
  // todo: craft valid signature for the overloaded send mnessage
  //New messages should not be sent if the state is not active | Unit test |
  function fuzz_noMessageIfNotActiveL2(address _to, uint256 _amount, uint32 _minGasLimit) public AgentOrDeployer {
    // Insure we're using the correct xdom sender
    require(mockMessenger.xDomainMessageSender() == address(l2Adapter));

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
      assert(!l2Adapter.isMessagingDisabled());
      assert(usdcBridged.balanceOf(currentCaller) == _fromBalanceBefore - _amount);
      assert(usdcMainnet.balanceOf(_to) == _toBalanceBefore + _amount);
    } catch {
      assert(l2Adapter.isMessagingDisabled());
      assert(usdcBridged.balanceOf(currentCaller) == _fromBalanceBefore);
      assert(usdcMainnet.balanceOf(_to) == _toBalanceBefore);
    }
  }

  /////////////////////////////////////////////////////////////////////
  //                     Echidna context fuzzer                      //
  /////////////////////////////////////////////////////////////////////

  /////////////////////////////////////////////////////////////////////
  //                          Initial setup                          //
  /////////////////////////////////////////////////////////////////////

  function _setupMockBridge() internal {
    mockMessenger.initialize(address(l1Adapter));
  }

  function _setupUsdc() internal {
    hevm.prank(usdcMainnet.masterMinter());
    usdcMainnet.configureMinter(address(_usdcMinter), type(uint256).max);
  }

  // Deploy: USDC L1, factory L1, L1 adapter
  function _mainnetSetup() internal returns (IL1OpUSDCFactory.L2Deployments memory _l2Deployments) {
    address targetAddress;
    uint256 size = USDC_IMPLEMENTATION_CREATION_CODE.length;
    bytes memory _usdcBytecode = USDC_IMPLEMENTATION_CREATION_CODE;

    assembly {
      targetAddress := create(0, add(_usdcBytecode, 0x20), size) // Skip the 32 bytes encoded length.
    }

    usdcMainnet = IUSDC(targetAddress);

    bytes[] memory usdcInitTxns = new bytes[](3);
    usdcInitTxns[0] = USDCInitTxs.INITIALIZEV2;
    usdcInitTxns[1] = USDCInitTxs.INITIALIZEV2_1;
    usdcInitTxns[2] = USDCInitTxs.INITIALIZEV2_2;

    factory = new L1OpUSDCFactory(address(usdcMainnet));

    mockMessenger = MockBridge(0x4200000000000000000000000000000000000007);

    // owner is this contract, as managed in the agents handler
    _l2Deployments =
      IL1OpUSDCFactory.L2Deployments(address(this), USDC_IMPLEMENTATION_CREATION_CODE, usdcInitTxns, 3_000_000);

    (address _l1Adapter, address _l2Factory, address _l2Adapter) =
      factory.deploy(address(mockMessenger), address(this), _l2Deployments);

    l2Factory = L2OpUSDCFactory(_l2Factory);
    l1Adapter = L1OpUSDCBridgeAdapter(_l1Adapter);
    l2Adapter = L2OpUSDCBridgeAdapter(_l2Adapter);
  }

  // Send a (mock) message to the L2 messenger to deploy the L2 factory and the L2 adapter (which deploys usdc L2 too)
  function _l2Setup(IL1OpUSDCFactory.L2Deployments memory _l2Deployments) internal {
    IL2OpUSDCFactory.USDCInitializeData memory usdcInitializeData = IL2OpUSDCFactory.USDCInitializeData(
      factory.USDC_NAME(), factory.USDC_SYMBOL(), usdcMainnet.currency(), usdcMainnet.decimals()
    );

    bytes memory _l2factoryConstructorArgs = abi.encode(
      address(l1Adapter),
      _l2Deployments.l2AdapterOwner,
      _l2Deployments.usdcImplementationInitCode,
      usdcInitializeData, // encode?
      _l2Deployments.usdcInitTxs // encodePacked?
    );

    bytes memory _l2FactoryInitCode = bytes.concat(type(L2OpUSDCFactory).creationCode, _l2factoryConstructorArgs);

    // !!!! Nonce incremented to avoid collision !!!
    mockMessenger.relayMessage(
      mockMessenger.messageNonce() + 1,
      address(factory),
      address(0x13b0D85CcB8bf860b6b79AF3029fCA081AE9beF2),
      0,
      3_000_000,
      abi.encodeWithSignature(
        'deploy(uint256,bytes32,bytes)', 0, factory.deploymentsSaltCounter() + 1, _l2FactoryInitCode
      )
    );

    usdcBridged = IUSDC(l2Adapter.USDC());
  }

  /////////////////////////////////////////////////////////////////////
  //                Expose target contract selectors                 //
  /////////////////////////////////////////////////////////////////////

  // Expose all selectors, pranked
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
      try l1Adapter.sendMessage(_addressA, _uintA, _uint32A) {} catch {}
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
      try l1Adapter.sendMessage(_addressA, _uintA, _uint32A) {} catch {}
    } else if (_selectorIndex == 1) {
      try l1Adapter.sendMessage(_addressA, _addressB, _uintA, _bytesA, _uintB, _uint32A) {} catch {}
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

  function generateCallFactory() public AgentOrDeployer {}
}

/////////////////////////////////////////////////////////////////////
//                             L2 mock                             //
/////////////////////////////////////////////////////////////////////

// Relay any message
contract MockBridge is ITestCrossDomainMessenger {
  uint256 public messageNonce;
  address public l1Adapter;

  bool correctXDomSender;

  function initialize(address _l1Adapter) public {
    l1Adapter = _l1Adapter;
  }

  function xDomSenderSwitch() public {
    correctXDomSender = !correctXDomSender;
  }

  function OTHER_MESSENGER() external view returns (address) {
    return address(0);
  }

  function xDomainMessageSender() external view returns (address _sender) {
    _sender = correctXDomSender ? l1Adapter : address(123);
  }

  function sendMessage(address _target, bytes calldata _message, uint32 _minGasLimit) external {
    messageNonce++;
    _target.call(_message);
  }

  function relayMessage(
    uint256 _nonce,
    address _sender,
    address _target,
    uint256 _value,
    uint256 _minGasLimit,
    bytes calldata _message
  ) external payable {
    messageNonce++;
    (bool succ, bytes memory ret) = _target.call{value: _value}(_message);

    if (!succ) {
      revert(string(ret));
    }
  }
}

// Identical to the OZ implementation used
contract Create2Deployer {
  // solhint-disable custom-errors
  function deploy(uint256 _value, bytes32 _salt, bytes memory _initCode) public returns (address) {
    address addr;
    require(address(this).balance >= _value, 'Create2: insufficient balance');
    require(_initCode.length != 0, 'Create2: bytecode length is zero');

    assembly {
      addr := create2(_value, add(_initCode, 0x20), mload(_initCode), _salt)
    }
    require(addr != address(0), 'Create2: Failed on deploy');

    return addr;
  }
}