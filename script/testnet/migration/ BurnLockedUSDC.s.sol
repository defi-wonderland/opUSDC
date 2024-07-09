// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/Test.sol';
import {IL1OpUSDCBridgeAdapter} from 'interfaces/IL1OpUSDCBridgeAdapter.sol';

contract MigrateToNativeOp is Script {
  IL1OpUSDCBridgeAdapter public immutable L1_ADAPTER = IL1OpUSDCBridgeAdapter(vm.envAddress('L1_ADAPTER_OP_SEPOLIA'));
  address public burnCaller = vm.rememberKey(vm.envUint('SEPOLIA_OP_BURN_CALLER_PK'));

  function run() public {
    vm.startBroadcast(burnCaller);
    L1_ADAPTER.burnLockedUSDC();
    vm.stopBroadcast();
  }
}
