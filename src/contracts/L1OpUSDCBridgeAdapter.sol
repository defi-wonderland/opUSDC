// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {BaseOpUSDCBridgeAdapter} from 'contracts/BaseOpUSDCBridgeAdapter.sol';
import {ICrossDomainMessenger} from 'interfaces/external/ICrossDomainMessenger.sol';

contract L1OpUSDCBridgeAdapter is BaseOpUSDCBridgeAdapter {
  /**
   * @notice Construct the OpUSDCBridgeAdapter contract
   * @param _usdc The address of the USDC Contract to be used by the adapter
   * @param _messenger The address of the messenger contract
   */
  constructor(address _usdc, address _messenger) BaseOpUSDCBridgeAdapter(_usdc, _messenger) {}

  /**
   * @notice Send the message to the linked adapter to mint the bridged representation on the linked chain
   * @param _amount The amount of tokens to send
   * @param _minGasLimit Minimum gas limit that the message can be executed with
   */
  function send(uint256 _amount, uint32 _minGasLimit) external override linkedAdapterMustBeInitialized {
    // Ensure messaging is enabled
    if (isMessagingDisabled) revert IOpUSDCBridgeAdapter_MessagingDisabled();

    // Transfer the tokens to the contract
    IERC20(USDC).transferFrom(msg.sender, address(this), _amount);

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
      revert IOpUSDCBridgeAdapter_NotLinkedAdapter();
    }

    // Transfer the tokens to the user
    IERC20(USDC).transfer(_user, _amount);

    emit MessageReceived(_user, _amount);
  }
}
