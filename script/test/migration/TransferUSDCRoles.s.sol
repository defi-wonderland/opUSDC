// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script} from 'forge-std/Script.sol';
import {IL2OpUSDCBridgeAdapter} from 'interfaces/IL2OpUSDCBridgeAdapter.sol';

/// Warning: Script created only for testing purposes.
contract TransferUSDCRoles is Script {
  IL2OpUSDCBridgeAdapter public immutable L2_ADAPTER = IL2OpUSDCBridgeAdapter(vm.envAddress('L2_ADAPTER'));

  address public roleCaller = vm.rememberKey(vm.envUint('ROLE_CALLER_PK'));
  address public newOwner = vm.envAddress('NEW_USDC_OWNER');

  function run() public {
    vm.startBroadcast(roleCaller);
    L2_ADAPTER.transferUSDCRoles(newOwner);
    vm.stopBroadcast();
  }
}
