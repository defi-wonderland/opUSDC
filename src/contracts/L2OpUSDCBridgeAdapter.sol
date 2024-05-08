// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {OpUSDCBridgeAdapter} from 'contracts/universal/OpUSDCBridgeAdapter.sol';
import {IL2OpUSDCBridgeAdapter} from 'interfaces/IL2OpUSDCBridgeAdapter.sol';
import {ICrossDomainMessenger} from 'interfaces/external/ICrossDomainMessenger.sol';
import {IUSDC} from 'interfaces/external/IUSDC.sol';

contract L2OpUSDCBridgeAdapter is IL2OpUSDCBridgeAdapter, OpUSDCBridgeAdapter {
  /**
   * @notice Construct the OpUSDCBridgeAdapter contract
   * @param _usdc The address of the USDC Contract to be used by the adapter
   * @param _messenger The address of the messenger contract
   */
  constructor(address _usdc, address _messenger) OpUSDCBridgeAdapter(_usdc, _messenger) {}

  /**
   * @notice Send a message to the linked adapter to transfer the tokens to the user
   * @dev Burn the bridged representation acording to the amount sent on the message
   * @param _amount The amount of tokens to send
   * @param _minGasLimit Minimum gas limit that the message can be executed with
   */
  function send(uint256 _amount, uint32 _minGasLimit) external override linkedAdapterMustBeInitialized {
    // Ensure messaging is enabled
    if (isMessagingDisabled) revert IOpUSDCBridgeAdapter_MessagingDisabled();

    //Burn the tokens
    IUSDC(USDC).burn(msg.sender, _amount);

    // Send the message to the linked adapter
    ICrossDomainMessenger(MESSENGER).sendMessage(
      linkedAdapter, abi.encodeWithSignature('receiveMessage(address,uint256)', msg.sender, _amount), _minGasLimit
    );

    emit MessageSent(msg.sender, _amount, _minGasLimit);
  }

  /**
   * @notice Receive the message from the other chain and mint the bridged representation for the user
   * @dev This function should only be called when receiving a message to mint the bridged representation
   * @param _user The user to mint the bridged representation for
   * @param _amount The amount of tokens to mint
   */
  function receiveMessage(address _user, uint256 _amount) external override linkedAdapterMustBeInitialized {
    // Ensure the message is coming from the linked adapter
    if (msg.sender != MESSENGER || ICrossDomainMessenger(MESSENGER).xDomainMessageSender() != linkedAdapter) {
      revert IOpUSDCBridgeAdapter_InvalidSender();
    }

    // Mint the tokens to the user
    IUSDC(USDC).mint(_user, _amount);

    emit MessageReceived(_user, _amount);
  }

  /**
   * @notice Receive the stop messaging message from the linked adapter and stop outgoing messages
   */
  function receiveStopMessaging() external virtual linkedAdapterMustBeInitialized {
    // Ensure the message is coming from the linked adapter
    if (msg.sender != MESSENGER || ICrossDomainMessenger(MESSENGER).xDomainMessageSender() != linkedAdapter) {
      revert IOpUSDCBridgeAdapter_InvalidSender();
    }
    isMessagingDisabled = true;
    emit MessagingStopped();
  }
}
