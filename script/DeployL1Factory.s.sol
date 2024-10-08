// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {L1OpUSDCFactory} from 'contracts/L1OpUSDCFactory.sol';
import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/Test.sol';
import {IL1OpUSDCFactory} from 'interfaces/IL1OpUSDCFactory.sol';

contract DeployL1Factory is Script {
  address public deployer = vm.rememberKey(vm.envUint('PRIVATE_KEY'));
  address public usdc = vm.envAddress('USDC_ETHEREUM_PROXY');

  function run() public {
    vm.startBroadcast(deployer);
    console.log('Deploying L1OpUSDCFactory ...');
    IL1OpUSDCFactory _l1Factory = new L1OpUSDCFactory(usdc);
    console.log('L1OpUSDCFactory deployed at:', address(_l1Factory));
    /// NOTE: Hardcode the address on `L1_FACTORY` inside the `.env` or `.env.testnet` file
    vm.stopBroadcast();
  }
}
