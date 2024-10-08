// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script} from 'forge-std/Script.sol';
import {IL1OpUSDCBridgeAdapter} from 'interfaces/IL1OpUSDCBridgeAdapter.sol';

/// Warning: Script created only for testing purposes.
contract BurnLockedUSDC is Script {
  IL1OpUSDCBridgeAdapter public immutable L1_ADAPTER = IL1OpUSDCBridgeAdapter(vm.envAddress('L1_ADAPTER'));
  address public burnCaller = vm.rememberKey(vm.envUint('BURN_CALLER_PK'));

  function run() public {
    vm.startBroadcast(burnCaller);
    L1_ADAPTER.burnLockedUSDC();
    vm.stopBroadcast();
  }
}
