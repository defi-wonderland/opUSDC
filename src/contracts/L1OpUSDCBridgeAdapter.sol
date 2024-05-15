// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {OpUSDCBridgeAdapter} from 'contracts/universal/OpUSDCBridgeAdapter.sol';
import {IL1OpUSDCBridgeAdapter} from 'interfaces/IL1OpUSDCBridgeAdapter.sol';
import {ICrossDomainMessenger} from 'interfaces/external/ICrossDomainMessenger.sol';
import {IUSDC} from 'interfaces/external/IUSDC.sol';

contract L1OpUSDCBridgeAdapter is IL1OpUSDCBridgeAdapter, OpUSDCBridgeAdapter, Ownable {
  using SafeERC20 for IUSDC;

  /// @inheritdoc IL1OpUSDCBridgeAdapter
  uint256 public burnAmount;

  /**
   * @notice Construct the OpUSDCBridgeAdapter contract
   * @param _usdc The address of the USDC Contract to be used by the adapter
   * @param _messenger The address of the messenger contract
   * @param _linkedAdapter The address of the linked adapter
   */
  constructor(
    address _usdc,
    address _messenger,
    address _linkedAdapter
  ) OpUSDCBridgeAdapter(_usdc, _messenger, _linkedAdapter) Ownable(msg.sender) {}

  /**
   * @notice Sets the amount of USDC tokens that will be burned when the burnLockedUSDC function is called
   * @param _amount The amount of USDC tokens that will be burned
   * @dev Only callable by the owner
   */
  function setBurnAmount(uint256 _amount) external onlyOwner {
    burnAmount = _amount;

    emit BurnAmountSet(_amount);
  }

  /**
   * @notice Burns the USDC tokens locked in the contract
   * @dev The amount is determined by the burnAmount variable, which is set in the setBurnAmount function
   */
  function burnLockedUSDC() external onlyOwner {
    // Burn the USDC tokens
    IUSDC(USDC).burn(address(this), burnAmount);

    // Set the burn amount to 0
    burnAmount = 0;
  }

  /**
   * @notice Send the message to the linked adapter to mint the bridged representation on the linked chain
   * @param _to The target address on the destination chain
   * @param _amount The amount of tokens to send
   * @param _minGasLimit Minimum gas limit that the message can be executed with
   */
  function sendMessage(address _to, uint256 _amount, uint32 _minGasLimit) external override {
    // Ensure messaging is enabled
    if (isMessagingDisabled) revert IOpUSDCBridgeAdapter_MessagingDisabled();

    // Transfer the tokens to the contract
    IUSDC(USDC).safeTransferFrom(msg.sender, address(this), _amount);

    // Send the message to the linked adapter
    ICrossDomainMessenger(MESSENGER).sendMessage(
      LINKED_ADAPTER, abi.encodeWithSignature('receiveMessage(address,uint256)', _to, _amount), _minGasLimit
    );

    emit MessageSent(msg.sender, _to, _amount, _minGasLimit);
  }

  /**
   * @notice Receive the message from the other chain and transfer the tokens to the user
   * @dev This function should only be called when receiving a message to mint the bridged representation
   * @param _user The user to mint the bridged representation for
   * @param _amount The amount of tokens to mint
   */
  function receiveMessage(address _user, uint256 _amount) external override {
    if (msg.sender != MESSENGER || ICrossDomainMessenger(MESSENGER).xDomainMessageSender() != LINKED_ADAPTER) {
      revert IOpUSDCBridgeAdapter_InvalidSender();
    }

    // Transfer the tokens to the user
    IUSDC(USDC).safeTransfer(_user, _amount);

    emit MessageReceived(_user, _amount);
  }

  /**
   * @notice Send a message to the linked adapter to call receiveStopMessaging() and stop outgoing messages.
   * @dev Only callable by the owner of the adapter
   * @dev Setting isMessagingDisabled to true is an irreversible operation
   * @param _minGasLimit Minimum gas limit that the message can be executed with
   */
  function stopMessaging(uint32 _minGasLimit) external onlyOwner {
    // Ensure messaging is enabled
    if (isMessagingDisabled) revert IOpUSDCBridgeAdapter_MessagingDisabled();

    isMessagingDisabled = true;
    ICrossDomainMessenger(MESSENGER).sendMessage(
      LINKED_ADAPTER, abi.encodeWithSignature('receiveStopMessaging()'), _minGasLimit
    );
    emit MessagingStopped();
  }
}
