// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {L1OpUSDCFactory} from 'contracts/L1OpUSDCFactory.sol';
import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/Test.sol';
import {IL1OpUSDCFactory} from 'interfaces/IL1OpUSDCFactory.sol';
import {IUpgradeManager} from 'interfaces/IUpgradeManager.sol';
import {FactoryDeployAndSetup} from 'script/FactoryDeployAndSetup.sol';

contract L1FactoryDeployAndSetup is Script, FactoryDeployAndSetup {
  address public constant USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
  address public constant L1_MESSENGER_OP = 0x58Cc85b8D04EA49cC6DBd3CbFFd00B4B8D6cb3ef;
  address public constant L1_MESSENGER_BASE = 0xC34855F4De64F1840e5686e64278da901e261f20;
  address public deployer = vm.rememberKey(vm.envUint('SEPOLIA_DEPLOYER_PK'));
  address public usdcImplementation = vm.envAddress('SEPOLIA_USDC_IMPLEMENTATION');
  bytes32 public salt = vm.envBytes32('SALT');

  function run() public {
    vm.startBroadcast(deployer);

    MessengerExecutor[] memory _messengersExecutors = new MessengerExecutor[](2);
    _messengersExecutors[0] = MessengerExecutor(L1_MESSENGER_OP, deployer);
    _messengersExecutors[1] = MessengerExecutor(L1_MESSENGER_BASE, deployer);

    // TODO: Add proper init txs arrays for both USDC and adapter
    bytes[] memory _initTxs = new bytes[](0);

    _deployFactoryAndSetup(deployer, USDC, usdcImplementation, _initTxs, _initTxs, salt, _messengersExecutors);

    vm.stopBroadcast();
  }
}
