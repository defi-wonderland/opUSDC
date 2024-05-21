// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import {OpUSDCBridgeAdapter} from 'contracts/universal/OpUSDCBridgeAdapter.sol';
import {IL2OpUSDCBridgeAdapter} from 'interfaces/IL2OpUSDCBridgeAdapter.sol';
import {ICrossDomainMessenger} from 'interfaces/external/ICrossDomainMessenger.sol';
import {IUSDC} from 'interfaces/external/IUSDC.sol';

contract L2OpUSDCBridgeAdapter is IL2OpUSDCBridgeAdapter, Initializable, OpUSDCBridgeAdapter, UUPSUpgradeable {
  /// @inheritdoc IL2OpUSDCBridgeAdapter
  address public immutable MESSENGER;

  /**
   * @notice Construct the OpUSDCBridgeAdapter contract
   * @param _usdc The address of the USDC Contract to be used by the adapter
   * @param _messenger The address of the messenger contract
   * @param _linkedAdapter The address of the linked adapter
   * @dev The constructor is only used to initialize the OpUSDCBridgeAdapter immutable variables
   */
  /* solhint-disable no-unused-vars */
  constructor(address _usdc, address _messenger, address _linkedAdapter) OpUSDCBridgeAdapter(_usdc, _linkedAdapter) {
    MESSENGER = _messenger;
    _disableInitializers();
  }
  /* solhint-enable no-unused-vars */

  /**
   * @notice Modifier to check if the sender is the linked adapter through the messenger
   */
  modifier checkSender() {
    if (msg.sender != MESSENGER || ICrossDomainMessenger(MESSENGER).xDomainMessageSender() != LINKED_ADAPTER) {
      revert IOpUSDCBridgeAdapter_InvalidSender();
    }
    _;
  }

  /**
   * @notice Send a message to the linked adapter to transfer the tokens to the user
   * @dev Burn the bridged representation acording to the amount sent on the message
   * @param _to The target address on the destination chain
   * @param _amount The amount of tokens to send
   * @param _minGasLimit Minimum gas limit that the message can be executed with
   */
  function sendMessage(address _to, uint256 _amount, uint32 _minGasLimit) external override {
    // Ensure messaging is enabled
    if (isMessagingDisabled) revert IOpUSDCBridgeAdapter_MessagingDisabled();

    // Burn the tokens
    IUSDC(USDC).burn(msg.sender, _amount);

    // Send the message to the linked adapter
    ICrossDomainMessenger(MESSENGER).sendMessage(
      LINKED_ADAPTER, abi.encodeWithSignature('receiveMessage(address,uint256)', _to, _amount), _minGasLimit
    );

    emit MessageSent(msg.sender, _to, _amount, MESSENGER, _minGasLimit);
  }

  /**
   * @notice Receive the message from the other chain and mint the bridged representation for the user
   * @dev This function should only be called when receiving a message to mint the bridged representation
   * @param _user The user to mint the bridged representation for
   * @param _amount The amount of tokens to mint
   */
  function receiveMessage(address _user, uint256 _amount) external override checkSender {
    // Mint the tokens to the user
    IUSDC(USDC).mint(_user, _amount);
    emit MessageReceived(_user, _amount);
  }

  /**
   * @notice Receive the stop messaging message from the linked adapter and stop outgoing messages
   */
  function receiveStopMessaging() external checkSender {
    isMessagingDisabled = true;
    emit MessagingStopped();
  }

  /**
   * @notice Authorize the upgrade of the implementation of the contract
   * @param _newImplementation The address of the new implementation
   */
  function _authorizeUpgrade(address _newImplementation) internal override checkSender {}
}
