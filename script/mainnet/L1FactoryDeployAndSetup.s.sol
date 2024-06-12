// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {L1OpUSDCFactory} from 'contracts/L1OpUSDCFactory.sol';
import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/Test.sol';
import {IL1OpUSDCFactory} from 'interfaces/IL1OpUSDCFactory.sol';

contract L1FactoryDeployAndSetup is Script {
  address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
  address public constant L1_MESSENGER_OP = 0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1;
  address public constant L1_MESSENGER_BASE = 0x866E82a600A1414e583f7F13623F1aC5d58b0Afa;
  address public deployer = vm.rememberKey(vm.envUint('MAINNET_DEPLOYER_PK'));

  function run() public {
    vm.startBroadcast(deployer);

    console.log('Deploying L1OpUSDCFactory ...');
    IL1OpUSDCFactory _l1Factory = new L1OpUSDCFactory(USDC);
    console.log('L1OpUSDCFactory deployed at:', address(_l1Factory));

    vm.stopBroadcast();
  }
}
