// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IOpUSDCBridgeAdapter} from 'interfaces/IOpUSDCBridgeAdapter.sol';

abstract contract OpUSDCBridgeAdapter is IOpUSDCBridgeAdapter {
  /// @inheritdoc IOpUSDCBridgeAdapter
  address public immutable USDC;

  /// @inheritdoc IOpUSDCBridgeAdapter
  address public immutable LINKED_ADAPTER;

  /// @inheritdoc IOpUSDCBridgeAdapter
  mapping(address _user => uint256 _nonce) public userNonce;

  /**
   * @notice Construct the OpUSDCBridgeAdapter contract
   * @param _usdc The address of the USDC Contract to be used by the adapter
   * @param _linkedAdapter The address of the linked adapter
   */
  constructor(address _usdc, address _linkedAdapter) {
    USDC = _usdc;
    LINKED_ADAPTER = _linkedAdapter;
  }

  /**
   * @notice Receive the message from the other chain and mint the bridged representation for the user
   * @dev This function should only be called when receiving a message to mint the bridged representation
   * @param _user The user to mint the bridged representation for
   * @param _amount The amount of tokens to mint
   */
  function receiveMessage(address _user, uint256 _amount) external virtual;
}
