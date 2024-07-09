// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script} from 'forge-std/Script.sol';
import {IL2OpUSDCBridgeAdapter} from 'interfaces/IL2OpUSDCBridgeAdapter.sol';

/// NOTE: To be executed on L2
contract TransferUSDCRoles is Script {
  IL2OpUSDCBridgeAdapter public immutable L2_ADAPTER = IL2OpUSDCBridgeAdapter(vm.envAddress('L2_ADAPTER_OP'));

  address public roleCaller = vm.rememberKey(vm.envUint('OP_ROLE_CALLER_PK'));
  address public newOwner = vm.envAddress('OP_NEW_USDC_OWNER');

  function run() public {
    vm.startBroadcast(roleCaller);
    L2_ADAPTER.transferUSDCRoles(newOwner);
    vm.stopBroadcast();
  }
}
