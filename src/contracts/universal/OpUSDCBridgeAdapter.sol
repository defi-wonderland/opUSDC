// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IOpUSDCBridgeAdapter} from 'interfaces/IOpUSDCBridgeAdapter.sol';
import {ICrossDomainMessenger} from 'interfaces/external/ICrossDomainMessenger.sol';
import {IUSDC} from 'interfaces/external/IUSDC.sol';

abstract contract OpUSDCBridgeAdapter is Ownable, IOpUSDCBridgeAdapter {
  using SafeERC20 for IUSDC;

  /// @inheritdoc IOpUSDCBridgeAdapter
  address public immutable USDC;

  /// @inheritdoc IOpUSDCBridgeAdapter
  address public immutable MESSENGER;

  /// @inheritdoc IOpUSDCBridgeAdapter
  address public immutable LINKED_ADAPTER;

  /// @inheritdoc IOpUSDCBridgeAdapter
  bool public isMessagingDisabled;

  /**
   * @notice Construct the OpUSDCBridgeAdapter contract
   * @param _usdc The address of the USDC Contract to be used by the adapter
   * @param _messenger The address of the messenger contract
   * @param _linkedAdapter The address of the linked adapter
   */
  constructor(address _usdc, address _messenger, address _linkedAdapter) Ownable(msg.sender) {
    USDC = _usdc;
    MESSENGER = _messenger;
    LINKED_ADAPTER = _linkedAdapter;
  }

  /**
   * @notice Send the message to the linked adapter to mint the bridged representation on the linked chain
   * @param _amount The amount of tokens to send
   * @param _minGasLimit Minimum gas limit that the message can be executed with
   */
  function send(uint256 _amount, uint32 _minGasLimit) external virtual;

  /**
   * @notice Receive the message from the other chain and mint the bridged representation for the user
   * @dev This function should only be called when receiving a message to mint the bridged representation
   * @param _user The user to mint the bridged representation for
   * @param _amount The amount of tokens to mint
   */
  function receiveMessage(address _user, uint256 _amount) external virtual;

  /**
   * @notice Send a message to the linked adapter to call receiveStopMessaging() and stop outgoing messages.
   * @dev Only callable by the owner of the adapter
   * @dev Setting isMessagingDisabled to true is an irreversible operation
   * @param _minGasLimit Minimum gas limit that the message can be executed with
   */
  function stopMessaging(uint32 _minGasLimit) external virtual onlyOwner {
    isMessagingDisabled = true;
    ICrossDomainMessenger(MESSENGER).sendMessage(
      LINKED_ADAPTER, abi.encodeWithSignature('receiveStopMessaging()'), _minGasLimit
    );
    emit MessagingStopped();
  }

  /**
   * @notice Receive the stop messaging message from the linked adapter and stop outgoing messages
   */
  function receiveStopMessaging() external virtual {
    // Ensure the message is coming from the linked adapter
    if (msg.sender != MESSENGER || ICrossDomainMessenger(MESSENGER).xDomainMessageSender() != LINKED_ADAPTER) {
      revert IOpUSDCBridgeAdapter_InvalidSender();
    }
    isMessagingDisabled = true;
    emit MessagingStopped();
  }
}
