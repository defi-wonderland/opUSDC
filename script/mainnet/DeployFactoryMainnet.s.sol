// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {L1OpUSDCBridgeAdapter} from 'contracts/L1OpUSDCBridgeAdapter.sol';
import {OpUSDCFactory} from 'contracts/OpUSDCFactory.sol';
import {Script} from 'forge-std/Script.sol';
import {ICreateX} from 'interfaces/external/ICreateX.sol';
import {ICrossDomainMessenger} from 'interfaces/external/ICrossDomainMessenger.sol';

contract DeployFactoryMainnet is Script {
  ICrossDomainMessenger public constant L1_CROSS_DOMAIN_MESSENGER =
    ICrossDomainMessenger(0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1);
  ICrossDomainMessenger public constant L2_CROSS_DOMAIN_MESSENGER =
    ICrossDomainMessenger(0x4200000000000000000000000000000000000007);
  address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
  address public constant USDC_IMPLEMENTATION = 0x43506849D7C04F9138D1A2050bbF3A0c054402dd;
  ICreateX public constant L1_CREATEX = ICreateX(0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed);
  address public constant L2_CREATEX = 0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed;
  uint32 public constant MIN_GAS_LIMIT_USDC_DEPLOY = 2_000_000;
  uint32 public constant MIN_GAS_LIMIT_ADAPTER_DEPLOY = 2_000_000;

  address public deployer = vm.rememberKey(vm.envUint('MAINNET_DEPLOYER_PK'));

  function run() public {
    vm.startBroadcast(deployer);

    // Deploy OpUSDCFactory
    OpUSDCFactory factory = new OpUSDCFactory(
      L1_CROSS_DOMAIN_MESSENGER, L2_CROSS_DOMAIN_MESSENGER, USDC, USDC_IMPLEMENTATION, L1_CREATEX, L2_CREATEX
    );

    // Run the deploy function
    factory.deploy(MIN_GAS_LIMIT_USDC_DEPLOY, MIN_GAS_LIMIT_ADAPTER_DEPLOY);

    vm.stopBroadcast();
  }
}
