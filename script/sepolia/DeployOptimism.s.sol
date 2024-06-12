// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/Test.sol';
import {IL1OpUSDCFactory} from 'interfaces/IL1OpUSDCFactory.sol';
import {USDC_IMPLEMENTATION_CREATION_CODE} from 'script/utils/USDCImplementationCreationCode.sol';

contract DeployOptimism is Script {
  address public constant L1_MESSENGER = 0x58Cc85b8D04EA49cC6DBd3CbFFd00B4B8D6cb3ef;
  uint32 public constant MIN_GAS_LIMIT_FACTORY = 4_000_000;
  uint32 public constant MIN_GAS_LIMIT_DEPLOY = 8_000_000;
  IL1OpUSDCFactory public immutable L1_FACTORY = IL1OpUSDCFactory(vm.envAddress('L1_FACTORY_SEPOLIA'));

  address public deployer = vm.rememberKey(vm.envUint('SEPOLIA_DEPLOYER_PK'));

  function run() public {
    vm.startBroadcast(deployer);
    // Deploy the L2 contracts
    bytes32 _salt = bytes32('32');
    bytes[] memory _usdcInitTxs = new bytes[](0);
    (address _l2Factory, address _l1Adapter, address _l2Adapter) = L1_FACTORY.deployL2FactoryAndContracts(
      _salt,
      L1_MESSENGER,
      deployer,
      MIN_GAS_LIMIT_FACTORY,
      USDC_IMPLEMENTATION_CREATION_CODE,
      _usdcInitTxs,
      MIN_GAS_LIMIT_DEPLOY
    );
    vm.stopBroadcast();

    console.log('L1 Adapter:', _l1Adapter);
    console.log('L2 Factory:', _l2Factory);
    console.log('L2 Adapter:', _l2Adapter);
  }
}
