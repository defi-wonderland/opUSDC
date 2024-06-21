// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script} from 'forge-std/Script.sol';

import {console} from 'forge-std/Test.sol';
import {IL1OpUSDCFactory} from 'interfaces/IL1OpUSDCFactory.sol';
import {USDC_IMPLEMENTATION_CREATION_CODE} from 'script/utils/USDCImplementationCreationCode.sol';

contract DeployBase is Script {
  address public constant L1_MESSENGER = 0xC34855F4De64F1840e5686e64278da901e261f20;
  uint32 public constant MIN_GAS_LIMIT_FACTORY = 4_000_000;
  uint32 public constant MIN_GAS_LIMIT_DEPLOY = 8_000_000;
  IL1OpUSDCFactory public immutable L1_FACTORY = IL1OpUSDCFactory(vm.envAddress('L1_FACTORY_SEPOLIA'));

  address public deployer = vm.rememberKey(vm.envUint('SEPOLIA_DEPLOYER_PK'));

  function run() public {
    vm.startBroadcast(deployer);
    // Deploy the L2 contracts
    bytes[] memory _usdcInitTxs = new bytes[](0);
    IL1OpUSDCFactory.L2Deployments memory _l2Deployments = IL1OpUSDCFactory.L2Deployments({
      l2AdapterOwner: deployer,
      usdcImplementationInitCode: USDC_IMPLEMENTATION_CREATION_CODE,
      usdcInitTxs: _usdcInitTxs,
      minGasLimitCreate2Factory: MIN_GAS_LIMIT_FACTORY,
      minGasLimitDeploy: MIN_GAS_LIMIT_DEPLOY
    });
    (address _l1Adapter, address _l2Factory, address _l2Adapter) =
      L1_FACTORY.deploy(L1_MESSENGER, deployer, _l2Deployments);
    vm.stopBroadcast();

    console.log('L1 Adapter:', _l1Adapter);
    console.log('L2 Factory:', _l2Factory);
    console.log('L2 Adapter:', _l2Adapter);
  }
}
