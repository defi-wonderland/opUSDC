// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {L1OpUSDCFactory} from 'contracts/L1OpUSDCFactory.sol';
import {console} from 'forge-std/Test.sol';
import {IL1OpUSDCFactory} from 'interfaces/IL1OpUSDCFactory.sol';
import {IUpgradeManager} from 'interfaces/IUpgradeManager.sol';

contract FactoryDeployAndSetup {
  struct MessengerExecutor {
    address l1Messenger;
    address executor;
  }

  function _deployFactoryAndSetup(
    address _deployer,
    address _usdc,
    address _usdcImplementation,
    bytes[] memory _initTxsUsdc,
    address _adapterImplementation,
    bytes[] memory _initTxsAdapter,
    bytes32 _salt,
    MessengerExecutor[] memory _messengersExecutors
  ) internal {
    console.log('Deploying L1OpUSDCFactory ...');
    bytes32 _parsedSalt = keccak256(abi.encode(_salt, block.number, block.timestamp, blockhash(block.number - 1)));
    IL1OpUSDCFactory _l1Factory = new L1OpUSDCFactory(_usdc, _parsedSalt, _deployer);

    console.log('------ Deployments -------');
    console.log('----- L1 ------');
    console.log('L1OpUSDCFactory deployed at:', address(_l1Factory));
    console.log('L1OpUSDCBridgeAdapter deployed at:', address(_l1Factory.L1_ADAPTER_PROXY()));
    IUpgradeManager _upgradeManager = IUpgradeManager(_l1Factory.UPGRADE_MANAGER());
    console.log('L1 UpgradeManager deployed at:', address(_upgradeManager));
    console.log('----- L2 ------');
    console.log('L2Factory deployment address:', _l1Factory.L2_FACTORY());
    console.log('L2OpUSDCBridgeAdapter proxy deployment address:', _l1Factory.L2_ADAPTER_PROXY());
    console.log('L2 USDC proxy deployed deployment address:', _l1Factory.L2_USDC_PROXY());
    console.log('--------------------------');

    if (_usdcImplementation != address(0)) {
      console.log('Setting USDC implementation address ...');
      _l1Factory.UPGRADE_MANAGER().setBridgedUSDCImplementation(_usdcImplementation, _initTxsUsdc);
      console.log('USDC implementation address set to:', _usdcImplementation);
    }

    if (_adapterImplementation != address(0)) {
      console.log('Setting adapter implementation address ...');
      _l1Factory.UPGRADE_MANAGER().setL2AdapterImplementation(_adapterImplementation, _initTxsAdapter);
      console.log('Adapter implementation address set to:', _adapterImplementation);
    }

    uint256 _messengersLength = _messengersExecutors.length;
    if (_messengersLength > 0) {
      for (uint256 _i; _i < _messengersLength; _i++) {
        console.log(
          'Setting executor:', _messengersExecutors[_i].executor, 'for messenger:', _messengersExecutors[_i].l1Messenger
        );
        _upgradeManager.prepareDeploymentForMessenger(
          _messengersExecutors[_i].l1Messenger, _messengersExecutors[_i].executor
        );
        console.log('Executor set for messenger!');
      }
    }
  }
}
