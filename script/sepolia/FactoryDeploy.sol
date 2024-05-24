// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BytecodeDeployer} from 'contracts/BytecodeDeployer.sol';
import {L1OpUSDCFactory} from 'contracts/L1OpUSDCFactory.sol';
import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/Test.sol';
import {IL1OpUSDCFactory} from 'interfaces/IL1OpUSDCFactory.sol';

contract FactoryDeploy is Script {
  address public constant USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
  address public deployer = vm.rememberKey(vm.envUint('SEPOLIA_DEPLOYER_PK'));

  function run() public {
    vm.startBroadcast(deployer);

    console.log('Deploying L1OpUSDCFactory ...');
    IL1OpUSDCFactory _l1Factory = new L1OpUSDCFactory(USDC, deployer);
    console.log('L1OpUSDCFactory deployed at:', address(_l1Factory));

    console.log('L1OpUSDCBridgeAdapter deployed at:', address(_l1Factory.L1_ADAPTER()));
    console.log('L1 UpgradeManager deployed at:', address(_l1Factory.UPGRADE_MANAGER()));
    console.log('-----');
    console.log('aliased L1 factory deployment address:', _l1Factory.ALIASED_SELF());
    console.log('L2OpUSDCBridgeAdapter deployment address:', _l1Factory.L2_ADAPTER());
    console.log('L2 USDC proxy deployed deployment address:', _l1Factory.L2_USDC_PROXY());
    console.log('L2 USDC implementation deployed deployment address:', _l1Factory.L2_USDC_IMPLEMENTATION());

    vm.stopBroadcast();
  }
}
