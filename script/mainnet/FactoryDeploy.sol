// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {L1OpUSDCFactory} from 'contracts/L1OpUSDCFactory.sol';
import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/Test.sol';
import {IL1OpUSDCFactory} from 'interfaces/IL1OpUSDCFactory.sol';

contract FactoryDeploy is Script {
  address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
  address public deployer = vm.rememberKey(vm.envUint('MAINNET_DEPLOYER_PK'));

  function run() public {
    vm.startBroadcast(deployer);

    console.log('Deploying L1OpUSDCFactory ...');
    bytes32 _salt = keccak256(abi.encode(block.number, block.timestamp, blockhash(block.number - 1)));
    IL1OpUSDCFactory _l1Factory = new L1OpUSDCFactory(USDC, _salt, deployer);
    console.log('L1OpUSDCFactory deployed at:', address(_l1Factory));

    console.log('L1OpUSDCBridgeAdapter deployed at:', address(_l1Factory.L1_ADAPTER_PROXY()));
    console.log('L1 UpgradeManager deployed at:', address(_l1Factory.UPGRADE_MANAGER()));
    console.log('-----');
    console.log('L2Factory deployment address:', _l1Factory.L2_FACTORY());
    console.log('L2OpUSDCBridgeAdapter proxy deployment address:', _l1Factory.L2_ADAPTER_PROXY());
    console.log('L2 USDC proxy deployed deployment address:', _l1Factory.L2_USDC_PROXY());
    console.log('-----');
    // TODO: remove from here and create another script well defined
    console.log('Setting l2 usdc implementation address ...');
    bytes[] memory _initTxs = new bytes[](1);
    _l1Factory.UPGRADE_MANAGER().setBridgedUSDCImplementation(USDC, _initTxs);
    console.log('L2 USDC implementation address set to:', USDC);

    console.log('Setting l2 adapter implementation address ...');
    _l1Factory.UPGRADE_MANAGER().setL2AdapterImplementation(address(_l1Factory.L1_ADAPTER_PROXY()), _initTxs);
    console.log('L2 adapter implementation address set to:', USDC);

    vm.stopBroadcast();
  }
}
