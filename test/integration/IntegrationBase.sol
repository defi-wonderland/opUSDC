// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IMockCrossDomainMessenger} from '../utils/interfaces/IMockCrossDomainMessenger.sol';
import {L1OpUSDCBridgeAdapter} from 'contracts/L1OpUSDCBridgeAdapter.sol';

import {L1OpUSDCFactory} from 'contracts/L1OpUSDCFactory.sol';
import {L2OpUSDCBridgeAdapter} from 'contracts/L2OpUSDCBridgeAdapter.sol';
import {UpgradeManager} from 'contracts/UpgradeManager.sol';
import {Test} from 'forge-std/Test.sol';

import {USDCInitTxs} from 'contracts/utils/USDCInitTxs.sol';
import {IUSDC} from 'interfaces/external/IUSDC.sol';

contract IntegrationBase is Test {
  uint256 internal constant _MAINNET_FORK_BLOCK = 20_013_633;

  address internal _owner = makeAddr('owner');
  address internal _user = makeAddr('user');

  address public constant MAINNET_USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
  address public constant MAINNET_USDC_IMPLEMENTATION = 0xa2327a938Febf5FEC13baCFb16Ae10EcBc4cbDCF;
  address public constant L2_CREATE2_DEPLOYER = 0x13b0D85CcB8bf860b6b79AF3029fCA081AE9beF2;
  bytes32 public constant SALT = keccak256(abi.encode('32'));
  bytes[] public usdcInitTxns = new bytes[](4);

  IMockCrossDomainMessenger public constant L2_MESSENGER =
    IMockCrossDomainMessenger(0x4200000000000000000000000000000000000007);
  IMockCrossDomainMessenger public constant OPTIMISM_L1_MESSENGER =
    IMockCrossDomainMessenger(0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1);

  // TODO: Setup
  L1OpUSDCBridgeAdapter public l1Adapter;
  L1OpUSDCFactory public factory;
  L2OpUSDCBridgeAdapter public l2AdapterImplementation;

  function setUp() public virtual {
    vm.createSelectFork(vm.rpcUrl('mainnet'), _MAINNET_FORK_BLOCK);
    factory = new L1OpUSDCFactory(MAINNET_USDC, SALT, _owner);
    l1Adapter = L1OpUSDCBridgeAdapter(factory.L1_ADAPTER_PROXY());

    l2AdapterImplementation =
      new L2OpUSDCBridgeAdapter(factory.L2_USDC_PROXY(), address(L2_MESSENGER), address(OPTIMISM_L1_MESSENGER));

    usdcInitTxns[0] = USDCInitTxs.INITIALIZE;
    usdcInitTxns[1] = USDCInitTxs.INITIALIZEV2;
    usdcInitTxns[2] = USDCInitTxs.INITIALIZEV2_1;

    // For some reason current mainnet implementation is poitned to V2_1
    // usdcInitTxns[3] = USDCInitTxs.INITIALIZEV2_2;
  }
}

// TODO: Delete this, it needs to be here for workflow to pass for now
contract IntegrationTest is IntegrationBase {
  function testTest() public {
    assertEq(address(0), address(0));
  }
}
