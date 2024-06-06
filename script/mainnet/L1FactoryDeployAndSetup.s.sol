// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {L1OpUSDCFactory} from 'contracts/L1OpUSDCFactory.sol';
import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/Test.sol';
import {IL1OpUSDCFactory} from 'interfaces/IL1OpUSDCFactory.sol';
import {IUpgradeManager} from 'interfaces/IUpgradeManager.sol';
import {FactoryDeployAndSetup} from 'script/FactoryDeployAndSetup.sol';

contract L1FactoryDeployAndSetup is Script, FactoryDeployAndSetup {
  address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
  address public constant L1_MESSENGER_OP = 0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1;
  address public constant L1_MESSENGER_BASE = 0x866E82a600A1414e583f7F13623F1aC5d58b0Afa;
  address public deployer = vm.rememberKey(vm.envUint('MAINNET_DEPLOYER_PK'));
  address public usdcImplementation = vm.envAddress('MAINNET_USDC_IMPLEMENTATION');
  address public adapterImplementation = vm.envAddress('MAINNET_ADAPTER_IMPLEMENTATION');
  bytes32 public salt = vm.envBytes32('SALT');

  function run() public {
    vm.startBroadcast(deployer);

    MessengerExecutor[] memory _messengersExecutors = new MessengerExecutor[](2);
    _messengersExecutors[0] = MessengerExecutor(L1_MESSENGER_OP, deployer);
    _messengersExecutors[1] = MessengerExecutor(L1_MESSENGER_BASE, deployer);

    // TODO: Add proper init txs arrays for both USDC and adapter
    bytes[] memory _initTxs = new bytes[](0);

    _deployFactoryAndSetup(
      deployer, USDC, usdcImplementation, _initTxs, adapterImplementation, _initTxs, salt, _messengersExecutors
    );

    vm.stopBroadcast();
  }
}
