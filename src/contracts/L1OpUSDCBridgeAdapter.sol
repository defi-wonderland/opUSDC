// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {ECDSA} from '@openzeppelin/contracts/utils/cryptography/ECDSA.sol';
import {MessageHashUtils} from '@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol';
import {OpUSDCBridgeAdapter} from 'contracts/universal/OpUSDCBridgeAdapter.sol';
import {IL1OpUSDCBridgeAdapter} from 'interfaces/IL1OpUSDCBridgeAdapter.sol';
import {ICrossDomainMessenger} from 'interfaces/external/ICrossDomainMessenger.sol';
import {IUSDC} from 'interfaces/external/IUSDC.sol';

contract L1OpUSDCBridgeAdapter is OpUSDCBridgeAdapter, UUPSUpgradeable, IL1OpUSDCBridgeAdapter {
  using SafeERC20 for IUSDC;

  /// @inheritdoc IL1OpUSDCBridgeAdapter
  address public immutable UPGRADE_MANAGER;

  /// @inheritdoc IL1OpUSDCBridgeAdapter
  uint256 public burnAmount;

  /**
   * @notice modifier to check that the sender is the Upgrade Manager
   */
  modifier onlyUpgradeManager() {
    if (msg.sender != UPGRADE_MANAGER) revert IOpUSDCBridgeAdapter_InvalidSender();
    _;
  }

  /**
   * @notice Construct the OpUSDCBridgeAdapter contract
   * @param _usdc The address of the USDC Contract to be used by the adapter
   * @param _messenger The address of the messenger contract
   * @param _linkedAdapter The address of the linked adapter
   * @dev The constructor is only used to initialize the OpUSDCBridgeAdapter immutable variables
   */
  /* solhint-disable no-unused-vars */
  constructor(
    address _usdc,
    address _messenger,
    address _linkedAdapter,
    address _upgradeManager
  ) OpUSDCBridgeAdapter(_usdc, _messenger, _linkedAdapter) {
    UPGRADE_MANAGER = _upgradeManager;
  }
  /* solhint-enable no-unused-vars */

  /**
   * @notice Sets the amount of USDC tokens that will be burned when the burnLockedUSDC function is called
   * @param _amount The amount of USDC tokens that will be burned
   * @dev Only callable by the owner
   */
  function setBurnAmount(uint256 _amount) external onlyUpgradeManager {
    burnAmount = _amount;

    emit BurnAmountSet(_amount);
  }

  /**
   * @notice Burns the USDC tokens locked in the contract
   * @dev The amount is determined by the burnAmount variable, which is set in the setBurnAmount function
   */
  function burnLockedUSDC() external onlyUpgradeManager {
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
   * @notice Send the message to the linked adapter to mint the bridged representation on the linked chain
   * @param _to The target address on the destination chain
   * @param _amount The amount of tokens to send
   * @param _nonce The nonce of the user
   * @param _signature The signature of the user
   * @param _minGasLimit Minimum gas limit that the message can be executed with
   */
  function sendMessage(
    address _to,
    uint256 _amount,
    uint256 _nonce,
    bytes calldata _signature,
    uint32 _minGasLimit
  ) external override {
    // Ensure messaging is enabled
    if (isMessagingDisabled) revert IOpUSDCBridgeAdapter_MessagingDisabled();

    // Hash the message
    bytes32 _messageHash = keccak256(abi.encodePacked(address(this), block.chainid, _to, _amount, _nonce));

    // Recover the signer
    address _signer = ECDSA.recover(MessageHashUtils.toEthSignedMessageHash(_messageHash), _signature);

    // Check the nonce
    if (userNonce[_signer] != _nonce) revert IOpUSDCBridgeAdapter_InvalidNonce();

    // Increment the nonce
    userNonce[_signer]++;

    // Transfer the tokens to the contract
    IUSDC(USDC).safeTransferFrom(_signer, address(this), _amount);

    // Send the message to the linked adapter
    ICrossDomainMessenger(MESSENGER).sendMessage(
      LINKED_ADAPTER, abi.encodeWithSignature('receiveMessage(address,uint256)', _to, _amount), _minGasLimit
    );

    emit MessageSent(_signer, _to, _amount, _minGasLimit);
  }

  /**
   * @notice Send a message to the linked adapter to upgrade the implementation of the contract
   * @param _newImplementation The address of the new implementation
   * @param _data The data to be used in the upgrade call
   * @param _minGasLimit Minimum gas limit that the message can be executed with
   */
  function sendL2AdapterUpgrade(
    address _newImplementation,
    bytes calldata _data,
    uint32 _minGasLimit
  ) external onlyUpgradeManager {
    ICrossDomainMessenger(MESSENGER).sendMessage(
      LINKED_ADAPTER,
      abi.encodeWithSignature('upgradeToAndCall(address,bytes)', _newImplementation, _data),
      _minGasLimit
    );

    emit L2AdapterUpgradeSent(_newImplementation, _data, _minGasLimit);
  }

  /**
   * @notice Receive the message from the other chain and transfer the tokens to the user
   * @dev This function should only be called when receiving a message to mint the bridged representation
   * @param _user The user to mint the bridged representation for
   * @param _amount The amount of tokens to mint
   */
  function receiveMessage(address _user, uint256 _amount) external override checkSender {
    // Transfer the tokens to the user
    IUSDC(USDC).safeTransfer(_user, _amount);

    emit MessageReceived(_user, _amount);
  }

  /**
   * @notice Initiates the process to migrate the bridged USDC to native USDC
   * @param _l1Messenger The address of the L1 messenger
   * @param _circle The address to transfer ownerships to
   */
  function migrateToNative(address _l1Messenger, address _circle) external {
    // TODO: Implement this in future PR
  }

  /**
   * @notice Send a message to the linked adapter to call receiveStopMessaging() and stop outgoing messages.
   * @dev Only callable by the owner of the adapter
   * @dev Setting isMessagingDisabled to true is an irreversible operation
   * @param _minGasLimit Minimum gas limit that the message can be executed with
   */
  function stopMessaging(uint32 _minGasLimit) external onlyUpgradeManager {
    // Ensure messaging is enabled
    if (isMessagingDisabled) revert IOpUSDCBridgeAdapter_MessagingDisabled();

    isMessagingDisabled = true;
    ICrossDomainMessenger(MESSENGER).sendMessage(
      LINKED_ADAPTER, abi.encodeWithSignature('receiveStopMessaging()'), _minGasLimit
    );
    emit MessagingStopped();
  }

  /**
   * @notice Authorize the upgrade of the implementation of the contract
   * @param _newImplementation The address of the new implementation
   */
  function _authorizeUpgrade(address _newImplementation) internal override onlyUpgradeManager {}
}
