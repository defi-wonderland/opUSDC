// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {L1OpUSDCFactory} from 'contracts/L1OpUSDCFactory.sol';
import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/Test.sol';
import {IL1OpUSDCFactory} from 'interfaces/IL1OpUSDCFactory.sol';

contract DeployL1Factory is Script {
  //   address public deployer = vm.rememberKey(vm.envUint('PK'));
  //   address public usdc = vm.envAddress('USDC_ETHEREUM_IMPLEMENTATION');

  function deployFactory(uint256 _deployerPk, address _usdc) public returns (address _l1Factory) {
    address _deployer = vm.rememberKey(_deployerPk);
    vm.startBroadcast(_deployer);
    console.log('Deploying L1OpUSDCFactory ...');
    _l1Factory = address(new L1OpUSDCFactory(_usdc));
    console.log('L1OpUSDCFactory deployed at:', address(_l1Factory));
    vm.stopBroadcast();
  }
}
