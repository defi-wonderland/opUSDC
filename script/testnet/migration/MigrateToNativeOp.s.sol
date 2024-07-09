// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script} from 'forge-std/Script.sol';
import {IL1OpUSDCBridgeAdapter} from 'interfaces/IL1OpUSDCBridgeAdapter.sol';

/// Warning: Script created only for testing purposes.
contract MigrateToNativeOp is Script {
  uint32 public constant MIN_GAS_LIMIT_RECEIVE_L2 = 100_000;
  uint32 public constant MIN_GAS_LIMIT_SET_BURN_AMOUNT_L2 = 100_000;
  IL1OpUSDCBridgeAdapter public immutable L1_ADAPTER = IL1OpUSDCBridgeAdapter(vm.envAddress('L1_ADAPTER_OP_SEPOLIA'));

  address public owner = vm.rememberKey(vm.envUint('SEPOLIA_OWNER_PK'));
  address public roleCaller = vm.envAddress('OP_SEPOLIA_ROLE_CALLER');
  address public burnCaller = vm.envAddress('SEPOLIA_OP_BURN_CALLER');

  function run() public {
    vm.startBroadcast(owner);
    L1_ADAPTER.migrateToNative(roleCaller, burnCaller, MIN_GAS_LIMIT_RECEIVE_L2, MIN_GAS_LIMIT_SET_BURN_AMOUNT_L2);
    vm.stopBroadcast();
  }
}
