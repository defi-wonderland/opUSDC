// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script} from 'forge-std/Script.sol';
import {IL1OpUSDCFactory} from 'interfaces/IL1OpUSDCFactory.sol';

contract FactoryDeployMainnet is Script {
  address public constant L1_MESSENGER = 0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1;
  uint32 public constant MIN_GAS_LIMIT_FACTORY = 2_000_000;
  uint32 public constant MIN_GAS_LIMIT_DEPLOY = 6_000_000;
  IL1OpUSDCFactory public immutable L1_FACTORY = IL1OpUSDCFactory(vm.envAddress('L1_FACTORY_MAINNET'));
  address public deployer = vm.rememberKey(vm.envUint('MAINNET_DEPLOYER_PK'));
  address public usdcAdmin = vm.envAddress('OP_USDC_ADMIN');

  function run() public {
    vm.startBroadcast(deployer);
    // Deploy the L2 contracts
    L1_FACTORY.deployL2FactoryAndContracts(L1_MESSENGER, usdcAdmin, MIN_GAS_LIMIT_FACTORY, MIN_GAS_LIMIT_DEPLOY);
    vm.stopBroadcast();
  }
}