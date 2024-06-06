// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {L2OpUSDCBridgeAdapter} from 'contracts/L2OpUSDCBridgeAdapter.sol';
import {console} from 'forge-std/Test.sol';

import {IUpgradeManager} from 'interfaces/IUpgradeManager.sol';

contract DeployAndSetAdapterImplementation {
  function _deployAndSetAdapterImplementation(
    address _usdc,
    address _l2Messenger,
    address _l1Adapter,
    IUpgradeManager _upgradeManager,
    bytes[] memory _initTxs
  ) internal {
    console.log('Deploying L2OpUSDCBridgeAdapter ...');
    address _l2AdapterImplementation = address(new L2OpUSDCBridgeAdapter(_usdc, _l2Messenger, _l1Adapter));
    console.log('L2OpUSDCBridgeAdapter deployed at:', _l2AdapterImplementation);

    console.log('Setting L2OpUSDCBridgeAdapter implementation address ...');
    _upgradeManager.setL2AdapterImplementation(_l2AdapterImplementation, _initTxs);
    console.log('L2OpUSDCBridgeAdapter implementation address set to:', _l2AdapterImplementation);
  }
}
