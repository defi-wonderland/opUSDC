// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script} from 'forge-std/Script.sol';
import {IL2OpUSDCBridgeAdapter} from 'interfaces/IL2OpUSDCBridgeAdapter.sol';

/// Warning: Script created only to test for testing purposes. It simulates what Circle should do on L2 after the
/// migration is triggered
contract TransferUSDCRoles is Script {
  IL2OpUSDCBridgeAdapter public immutable L2_ADAPTER = IL2OpUSDCBridgeAdapter(vm.envAddress('L2_ADAPTER_OP_SEPOLIA'));

  address public roleCaller = vm.rememberKey(vm.envUint('OP_SEPOLIA_ROLE_CALLER_PK'));
  address public newOwner = vm.envAddress('OP_SEPOLIA_NEW_USDC_OWNER');

  function run() public {
    vm.startBroadcast(roleCaller);
    L2_ADAPTER.transferUSDCRoles(newOwner);
    vm.stopBroadcast();
  }
}
