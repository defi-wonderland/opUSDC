// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script} from 'forge-std/Script.sol';
import {IL1OpUSDCFactory} from 'interfaces/IL1OpUSDCFactory.sol';
import {ICrossDomainMessenger} from 'interfaces/external/ICrossDomainMessenger.sol';

contract FactoryDeployBase is Script {
  address public constant PORTAL = 0x49f53e41452C74589E85cA1677426Ba426459e85;
  uint32 public constant MIN_GAS_LIMIT = 12_000_000;
  IL1OpUSDCFactory public immutable L1_FACTORY = IL1OpUSDCFactory(vm.envAddress('L1_FACTORY_SEPOLIA'));

  address public deployer = vm.rememberKey(vm.envUint('SEPOLIA_DEPLOYER_PK'));

  function run() public {
    vm.startBroadcast(deployer);
    // Deploy the L2 contracts
    L1_FACTORY.deployL2UsdcAndAdapter(PORTAL, MIN_GAS_LIMIT);
    vm.stopBroadcast();
  }
}
