// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {IOpUSDCBridgeAdapter} from 'interfaces/IOpUSDCBridgeAdapter.sol';

abstract contract BaseOpUSDCBridgeAdapter is Ownable, IOpUSDCBridgeAdapter {
  /// @inheritdoc IOpUSDCBridgeAdapter
  address public immutable USDC;

  /// @inheritdoc IOpUSDCBridgeAdapter
  address public immutable MESSENGER;

  /// @inheritdoc IOpUSDCBridgeAdapter
  address public linkedAdapter;

  /**
   * @notice Construct the OpUSDCBridgeAdapter contract
   * @dev On L2 the _lockbox param should be address(0)
   * @param _USDC The address of the USDC Contract to be used by the adapter
   * @param _messenger The address of the messenger contract
   */
  constructor(address _USDC, address _messenger) Ownable(msg.sender) {
    USDC = _USDC;
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

  /**
   * @notice Send the message to the linked adapter to mint the bridged representation on the linked chain
   * @param _isCanonical Whether the user is using the canonical USDC or the bridged representation
   * @param _amount The amount of tokens to send
   * @param _minGasLimit Minimum gas limit that the message can be executed with
   */
  function send(bool _isCanonical, uint256 _amount, uint32 _minGasLimit) external virtual;

  /**
   * @notice Receive the message from the other chain and mint the bridged representation for the user
   * @dev This function should only be called when receiving a message to mint the bridged representation
   * @param _user The user to mint the bridged representation for
   * @param _amount The amount of tokens to mint
   */
  function receiveMessage(address _user, uint256 _amount) external virtual;
}
