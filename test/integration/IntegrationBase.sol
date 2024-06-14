// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {AddressAliasHelper} from 'test/utils/AddressAliasHelper.sol';
import {USDC_IMPLEMENTATION_CREATION_CODE} from 'test/utils/USDCImplementationCreationCode.sol';
import {IMockCrossDomainMessenger} from 'test/utils/interfaces/IMockCrossDomainMessenger.sol';

import {L1OpUSDCBridgeAdapter} from 'contracts/L1OpUSDCBridgeAdapter.sol';

import {IL1OpUSDCFactory, L1OpUSDCFactory} from 'contracts/L1OpUSDCFactory.sol';

import {L2OpUSDCBridgeAdapter} from 'contracts/L2OpUSDCBridgeAdapter.sol';
import {L2OpUSDCFactory} from 'contracts/L2OpUSDCFactory.sol';
import {Test} from 'forge-std/Test.sol';

import {USDCInitTxs} from 'contracts/utils/USDCInitTxs.sol';

contract IntegrationBase is Test {
  // Constants
  uint256 internal constant _MAINNET_FORK_BLOCK = 20_076_176;
  uint256 internal constant _OPTIMISM_FORK_BLOCK = 121_300_856;
  address public constant MAINNET_USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
  address public constant MAINNET_USDC_IMPLEMENTATION = 0xa2327a938Febf5FEC13baCFb16Ae10EcBc4cbDCF;
  address public constant L2_CREATE2_DEPLOYER = 0x13b0D85CcB8bf860b6b79AF3029fCA081AE9beF2;
  IMockCrossDomainMessenger public constant L2_MESSENGER =
    IMockCrossDomainMessenger(0x4200000000000000000000000000000000000007);
  IMockCrossDomainMessenger public constant OPTIMISM_L1_MESSENGER =
    IMockCrossDomainMessenger(0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1);
  bytes32 public constant SALT = keccak256(abi.encode('32'));

  // Fork variables
  uint256 public optimism;
  uint256 public mainnet;

  // EOA addresses
  address internal _owner = makeAddr('owner');
  address internal _user = makeAddr('user');

  // Helper variables
  bytes[] public usdcInitTxns = new bytes[](3);
  bytes public initialize;

  // OpUSDC Protocol
  L1OpUSDCBridgeAdapter public l1Adapter;
  L1OpUSDCFactory public factory;
  L2OpUSDCBridgeAdapter public l2Adapter;

  function setUp() public virtual {
    mainnet = vm.createFork(vm.rpcUrl('mainnet'), _MAINNET_FORK_BLOCK);
    optimism = vm.createFork(vm.rpcUrl('optimism'), _OPTIMISM_FORK_BLOCK);

    // NOTE: This will change in a future PR so defining here to make refactoring easier later
    initialize = abi.encodeWithSignature(
      'initialize(string,string,string,uint8,address,address,address,address)',
      '',
      '',
      '',
      0,
      address(1),
      address(1),
      address(1),
      address(1)
    );

    factory = new L1OpUSDCFactory(MAINNET_USDC);

    usdcInitTxns[0] = initialize;
    usdcInitTxns[1] = USDCInitTxs.INITIALIZEV2;
    usdcInitTxns[2] = USDCInitTxs.INITIALIZEV2_1;

    IL1OpUSDCFactory.L2Deployments memory _l2Deployments =
      IL1OpUSDCFactory.L2Deployments(_owner, USDC_IMPLEMENTATION_CREATION_CODE, usdcInitTxns, 3_000_000);

    vm.selectFork(mainnet);

    vm.startPrank(_owner);
    (address _l2Factory, address _l1Adapter, address _l2Adapter) =
      factory.deployL2FactoryAndContracts(SALT, address(OPTIMISM_L1_MESSENGER), 3_000_000, _owner, _l2Deployments);
    vm.stopPrank();

    l1Adapter = L1OpUSDCBridgeAdapter(_l1Adapter);

    vm.selectFork(optimism);
    _relayL2Deployments(_l1Adapter, _l2Factory, _l2Adapter, _l2Deployments);

    // Make foundry know these two address exist on both forks
    vm.makePersistent(address(l1Adapter));
    vm.makePersistent(address(l2Adapter));
  }

  function _relayL2Deployments(
    address _l1Adapter,
    address _l2Factory,
    address _l2Adapter,
    IL1OpUSDCFactory.L2Deployments memory _l2Deployments
  ) internal {
    uint256 _messageNonce = L2_MESSENGER.messageNonce();
    bytes memory _l2FactoryCreationCode = type(L2OpUSDCFactory).creationCode;
    bytes memory _l2FactoryCArgs = abi.encode(address(factory));
    bytes memory _l2FactoryInitCode = bytes.concat(_l2FactoryCreationCode, _l2FactoryCArgs);

    vm.startPrank(AddressAliasHelper.applyL1ToL2Alias(address(OPTIMISM_L1_MESSENGER)));

    L2_MESSENGER.relayMessage(
      _messageNonce + 1,
      address(factory),
      address(L2_CREATE2_DEPLOYER),
      0,
      3_000_000,
      abi.encodeWithSignature('deploy(uint256,bytes32,bytes)', 0, SALT, _l2FactoryInitCode)
    );

    L2_MESSENGER.relayMessage(
      _messageNonce + 2,
      address(factory),
      address(_l2Factory),
      0,
      8_000_000,
      abi.encodeWithSelector(
        L2OpUSDCFactory.deploy.selector,
        _l1Adapter,
        _l2Deployments.l2AdapterOwner,
        _l2Deployments.usdcImplementationInitCode,
        _l2Deployments.usdcInitTxs
      )
    );

    vm.stopPrank();

    l2Adapter = L2OpUSDCBridgeAdapter(_l2Adapter);
  }
}

contract IntegrationSetup is IntegrationBase {
  function testSetup() public {
    vm.selectFork(mainnet);
    assertEq(l1Adapter.LINKED_ADAPTER(), address(l2Adapter));

    vm.selectFork(optimism);
    assertEq(l2Adapter.LINKED_ADAPTER(), address(l1Adapter));
  }
}
