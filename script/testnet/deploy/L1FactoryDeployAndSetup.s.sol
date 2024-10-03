// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {L1OpUSDCFactory} from 'contracts/L1OpUSDCFactory.sol';
import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/Test.sol';
import {IL1OpUSDCFactory} from 'interfaces/IL1OpUSDCFactory.sol';

contract L1FactoryDeployAndSetup is Script {
  address public constant USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
  address public deployer = vm.rememberKey(vm.envUint('TESTNET_PK'));

  function run() public {
    vm.createSelectFork(vm.rpcUrl(vm.envString('TESTNET_RPC')));
    vm.startBroadcast(deployer);
    console.log('Deploying L1OpUSDCFactory ...');
    IL1OpUSDCFactory _l1Factory = new L1OpUSDCFactory(USDC);
    console.log('L1OpUSDCFactory deployed at:', address(_l1Factory));
    /// NOTE: Hardcode the address on `L1_FACTORY_TESTNET` inside the `.env` file
    vm.stopBroadcast();
  }
}
