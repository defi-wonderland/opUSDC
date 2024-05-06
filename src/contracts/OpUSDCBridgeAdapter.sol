// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IOpUSDCBridgeAdapter} from 'interfaces/IOpUSDCBridgeAdapter.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';

contract OpUSDCBridgeAdapter is IOpUSDCBridgeAdapter, Ownable {
  /// @inheritdoc IOpUSDCBridgeAdapter
  address public immutable BRIDGED_USDC;

  /// @inheritdoc IOpUSDCBridgeAdapter
  address public immutable LOCKBOX;

  /// @inheritdoc IOpUSDCBridgeAdapter
  address public immutable MESSENGER;

  /// @inheritdoc IOpUSDCBridgeAdapter
  address public linkedAdapter;

  /**
   * @notice Construct the OpUSDCBridgeAdapter contract
   * @dev On L2 the _lockbox param should be address(0)
   * @param _bridgedUSDC The address of the Bridged USDC contract
   * @param _lockbox The address of the lockbox contract
   * @param _messenger The address of the messenger contract
   */
  constructor(address _bridgedUSDC, address _lockbox, address _messenger) {
    BRIDGED_USDC = _bridgedUSDC;
    LOCKBOX = _lockbox;
    MESSENGER = _messenger;
  }

  /**
   * @notice Set the linked adapter
   * @dev Only the owner can call this function
   * @param _linkedAdapter The address of the linked adapter
   */
  function setLinkedAdapter(address _linkedAdapter) external onlyOwner {
    linkedAdapter = _linkedAdapter;
    emit LinkedAdapterSet(_linkedAdapter);
  }
}
