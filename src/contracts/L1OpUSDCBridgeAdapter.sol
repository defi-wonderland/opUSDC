// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {OpUSDCBridgeAdapter} from 'contracts/universal/OpUSDCBridgeAdapter.sol';
import {IL1OpUSDCBridgeAdapter} from 'interfaces/IL1OpUSDCBridgeAdapter.sol';
import {ICrossDomainMessenger} from 'interfaces/external/ICrossDomainMessenger.sol';
import {IUSDC} from 'interfaces/external/IUSDC.sol';

contract L1OpUSDCBridgeAdapter is IL1OpUSDCBridgeAdapter, OpUSDCBridgeAdapter {
  /// @inheritdoc IL1OpUSDCBridgeAdapter
  uint256 public burnAmount;

  /**
   * @notice Construct the OpUSDCBridgeAdapter contract
   * @param _usdc The address of the USDC Contract to be used by the adapter
   * @param _messenger The address of the messenger contract
   */
  constructor(address _usdc, address _messenger) OpUSDCBridgeAdapter(_usdc, _messenger) {}

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
  }

  /**
   * @notice Send the message to the linked adapter to mint the bridged representation on the linked chain
   * @param _amount The amount of tokens to send
   * @param _minGasLimit Minimum gas limit that the message can be executed with
   */
  function send(uint256 _amount, uint32 _minGasLimit) external override linkedAdapterMustBeInitialized {
    // Ensure the linked adapter is set
    if (linkedAdapter == address(0)) revert IOpUSDCBridgeAdapter_LinkedAdapterNotSet();

    // Transfer the tokens to the contract
    IUSDC(USDC).transferFrom(msg.sender, address(this), _amount);

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
    // TODO: Add logic to check that messaging wasnt stopped

    // Ensure the message is coming from the linked adapter
    if (msg.sender != MESSENGER || ICrossDomainMessenger(MESSENGER).xDomainMessageSender() != linkedAdapter) {
      revert IOpUSDCBridgeAdapter_NotLinkedAdapter();
    }

    // Transfer the tokens to the user
    IUSDC(USDC).transfer(_user, _amount);

    emit MessageReceived(_user, _amount);
  }
}
