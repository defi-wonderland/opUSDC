// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {L1OpUSDCFactory} from 'contracts/L1OpUSDCFactory.sol';
import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/Test.sol';
import {IL1OpUSDCFactory} from 'interfaces/IL1OpUSDCFactory.sol';

abstract contract FactoryDeploy is Script {
  function _factoryDeploy(address _deployer, IL1OpUSDCFactory.DeployParams memory _params) internal {
    vm.startBroadcast(_deployer);

    console.log('Deploying L1OpUSDCFactory ...');
    IL1OpUSDCFactory factory = new L1OpUSDCFactory();
    console.log('L1OpUSDCFactory deployed at:', address(factory));

    console.log('Running the deploy function ...');
    IL1OpUSDCFactory.DeploymentAddresses memory _deploymentAddresses = factory.deploy(_params);
    console.log('L1OpUSDCBridgeAdapter deployed at:', _deploymentAddresses.l1Adapter);
    console.log('L2OpUSDCBridgeAdapter deployment address:', _deploymentAddresses.l2Adapter);
    console.log('L2 USDC proxy deployed deployment address:', _deploymentAddresses.l2UsdcProxy);
    console.log('L2 USDC implementation deployed deployment address:', _deploymentAddresses.l2UsdcImplementation);
    console.log('L2OpUSDCFactory deployed at:', _deploymentAddresses.l2Factory);

    vm.stopBroadcast();
  }
}
