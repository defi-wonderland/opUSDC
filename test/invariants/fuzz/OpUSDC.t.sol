// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {EchidnaTest} from '../AdvancedTestsUtils.sol';

// https://github.com/crytic/building-secure-contracts/blob/master/program-analysis/echidna/advanced/testing-bytecode.mdq
import {USDC_IMPLEMENTATION_CREATION_CODE} from 'test/utils/USDCImplementationCreationCode.sol';

import {L1OpUSDCBridgeAdapter} from 'contracts/L1OpUSDCBridgeAdapter.sol';
import {IL1OpUSDCFactory, L1OpUSDCFactory} from 'contracts/L1OpUSDCFactory.sol';
import {L2OpUSDCBridgeAdapter} from 'contracts/L2OpUSDCBridgeAdapter.sol';
import {L2OpUSDCFactory} from 'contracts/L2OpUSDCFactory.sol';
import {USDCInitTxs} from 'contracts/utils/USDCInitTxs.sol';
import {IL2OpUSDCFactory} from 'interfaces/IL2OpUSDCFactory.sol';
import {IUSDC} from 'interfaces/external/IUSDC.sol';

import {IMockCrossDomainMessenger} from 'test/utils/interfaces/IMockCrossDomainMessenger.sol';

contract OpUsdcTest is EchidnaTest {
  IUSDC usdcMainnet;
  IUSDC usdcBridged;

  L1OpUSDCBridgeAdapter public l1Adapter;
  L1OpUSDCFactory public factory;

  L2OpUSDCBridgeAdapter public l2Adapter;
  L2OpUSDCFactory public l2Factory;

  MockBridge public mockMessenger;
  Create2Deployer public create2Deployer;

  constructor() {
    create2Deployer = new Create2Deployer();
    mockMessenger = new MockBridge();

    IL1OpUSDCFactory.L2Deployments memory _l2Deployments = _mainnetSetup();
    _l2Setup(_l2Deployments);
  }

  function fuzz_testDeployments() public {
    assert(l2Adapter.LINKED_ADAPTER() == address(l1Adapter));
    assert(l2Adapter.MESSENGER() == address(mockMessenger));
    assert(l2Adapter.USDC() == address(usdcBridged));

    assert(l1Adapter.LINKED_ADAPTER() == address(l2Adapter));
    assert(l1Adapter.MESSENGER() == address(mockMessenger));
    assert(l1Adapter.USDC() == address(usdcMainnet));
  }

  function test_test() public {
    assert(true);
  }

  /////////////////////////////////////////////////////////////////////
  //                          Initial setup                          //
  /////////////////////////////////////////////////////////////////////

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

    // owner is this contract, as managed in the agents handler
    _l2Deployments =
      IL1OpUSDCFactory.L2Deployments(address(this), USDC_IMPLEMENTATION_CREATION_CODE, usdcInitTxns, 3_000_000);

    (address _l2Factory, address _l1Adapter, address _l2Adapter) = factory.deployL2FactoryAndContracts(
      keccak256(abi.encode('32')), address(mockMessenger), 3_000_000, address(this), _l2Deployments
    );

    l2Factory = L2OpUSDCFactory(_l2Factory);
    l1Adapter = L1OpUSDCBridgeAdapter(_l1Adapter);
    l2Adapter = L2OpUSDCBridgeAdapter(_l2Adapter);
  }

  // Send a (mock) message to the L2 messenger to deploy the L2 factory and the L2 adapter (which deploys usdc L2 too)
  function _l2Setup(IL1OpUSDCFactory.L2Deployments memory _l2Deployments) internal {
    bytes memory _l2FactoryInitCode = bytes.concat(type(L2OpUSDCFactory).creationCode, abi.encode(address(factory)));

    mockMessenger.relayMessage(
      mockMessenger.messageNonce() + 1,
      address(factory),
      address(create2Deployer),
      0,
      3_000_000,
      abi.encodeWithSignature('deploy(uint256,bytes32,bytes)', 0, keccak256(abi.encode('32')), _l2FactoryInitCode)
    );

    IL2OpUSDCFactory.USDCInitializeData memory usdcInitializeData =
      IL2OpUSDCFactory.USDCInitializeData('USD Coin', 'USDC', usdcMainnet.currency(), usdcMainnet.decimals());

    mockMessenger.relayMessage(
      mockMessenger.messageNonce() + 2,
      address(factory),
      address(l2Factory),
      0,
      8_000_000,
      abi.encodeWithSelector(
        L2OpUSDCFactory.deploy.selector,
        l1Adapter,
        _l2Deployments.l2AdapterOwner,
        _l2Deployments.usdcImplementationInitCode,
        usdcInitializeData,
        _l2Deployments.usdcInitTxs
      )
    );

    usdcBridged = IUSDC(l2Adapter.USDC());
  }
}

/////////////////////////////////////////////////////////////////////
//                             L2 mock                             //
/////////////////////////////////////////////////////////////////////

// Relay any message
contract MockBridge is IMockCrossDomainMessenger {
  uint256 public messageNonce;

  function OTHER_MESSENGER() external view returns (address) {
    return address(0);
  }

  function xDomainMessageSender() external view returns (address _sender) {
    return msg.sender;
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
    _target.call{value: _value}(_message);
    messageNonce++;
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