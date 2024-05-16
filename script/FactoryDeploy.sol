// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {OpUSDCFactory} from 'contracts/OpUSDCFactory.sol';
import {console} from 'forge-std/Console.sol';
import {Script} from 'forge-std/Script.sol';
import {IOpUSDCFactory} from 'interfaces/IOpUSDCFactory.sol';

abstract contract FactoryDeploy is Script {
  function _factoryDeploy(
    address _deployer,
    address _usdc,
    address _createX,
    uint256 _salt,
    IOpUSDCFactory.DeployParams memory _params
  ) internal {
    vm.startBroadcast(_deployer);

    console.log('Deploying OpUSDCFactory ...');
    IOpUSDCFactory factory = new OpUSDCFactory(_usdc, _createX, _salt);
    console.log('OpUSDCFactory deployed at:', address(factory));

    console.log('Running the deploy function ...');
    IOpUSDCFactory.DeploymentAddresses memory _deploymentAddresses = factory.deploy(_params);
    console.log('L1OpUSDCBridgeAdapter deployed at:', _deploymentAddresses.l1Adapter);
    console.log('L2OpUSDCBridgeAdapter deployment address:', _deploymentAddresses.l2Adapter);
    console.log('L2 USDC proxy deployed deployment address:', _deploymentAddresses.l2UsdcProxy);
    console.log('L2 USDC implementation deployed deployment address:', _deploymentAddresses.l2UsdcImplementation);

    vm.stopBroadcast();
  }
}
