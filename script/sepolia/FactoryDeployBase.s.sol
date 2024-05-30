// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script} from 'forge-std/Script.sol';
import {IL1OpUSDCFactory} from 'interfaces/IL1OpUSDCFactory.sol';

contract FactoryDeployBase is Script {
  address public constant L1_MESSENGER = 0xC34855F4De64F1840e5686e64278da901e261f20;
  uint32 public constant MIN_GAS_LIMIT_FACTORY = 4_000_000;
  uint32 public constant MIN_GAS_LIMIT_DEPLOY = 8_000_000;
  IL1OpUSDCFactory public immutable L1_FACTORY = IL1OpUSDCFactory(vm.envAddress('L1_FACTORY_SEPOLIA'));

  address public deployer = vm.rememberKey(vm.envUint('SEPOLIA_DEPLOYER_PK'));

  function run() public {
    vm.startBroadcast(deployer);
    // Deploy the L2 contracts
    L1_FACTORY.deployL2UsdcAndAdapter(L1_MESSENGER, MIN_GAS_LIMIT_FACTORY, MIN_GAS_LIMIT_DEPLOY);
    vm.stopBroadcast();
  }
}
