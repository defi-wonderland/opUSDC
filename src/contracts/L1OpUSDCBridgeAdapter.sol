// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {OpUSDCBridgeAdapter} from 'contracts/universal/OpUSDCBridgeAdapter.sol';
import {IL1OpUSDCBridgeAdapter} from 'interfaces/IL1OpUSDCBridgeAdapter.sol';
import {ICrossDomainMessenger} from 'interfaces/external/ICrossDomainMessenger.sol';
import {IUSDC} from 'interfaces/external/IUSDC.sol';

/**
 * @title L1OpUSDCBridgeAdapter
 * @notice L1OpUSDCBridgeAdapter is a contract that bridges Bridged USDC from L1 to L2 and and receives it from L2.
 * It is also in charge of pausing and resuming messaging between the L1 and L2 adapters, and properly initiating the
 * migration process to the for bridged USDC to native.
 */
contract L1OpUSDCBridgeAdapter is IL1OpUSDCBridgeAdapter, OpUSDCBridgeAdapter {
  using SafeERC20 for IUSDC;

  /// @inheritdoc IL1OpUSDCBridgeAdapter
  uint256 public burnAmount;

  /// @inheritdoc IL1OpUSDCBridgeAdapter
  address public burnCaller;

  /// @inheritdoc IL1OpUSDCBridgeAdapter
  Status public messengerStatus;

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
   * @notice Construct the OpUSDCBridgeAdapter contract
   * @param _usdc The address of the USDC Contract to be used by the adapter
   * @param _messenger The address of the L1 messenger
   * @param _linkedAdapter The address of the linked adapter
   * @param _owner The address of the owner of the contract
   * @dev The constructor is only used to initialize the OpUSDCBridgeAdapter immutable variables
   */
  constructor(
    address _usdc,
    address _messenger,
    address _linkedAdapter,
    address _owner
  ) OpUSDCBridgeAdapter(_usdc, _messenger, _linkedAdapter, _owner) {}

  /*///////////////////////////////////////////////////////////////
                              MIGRATION
  ///////////////////////////////////////////////////////////////*/

  /**
   * @notice Initiates the process to migrate the bridged USDC to native USDC
   * @param _roleCaller The address that will be allowed to transfer the usdc roles
   * @param _burnCaller The address that will be allowed to call this contract to burn the USDC tokens
   * @param _minGasLimitReceiveOnL2 Minimum gas limit that the message can be executed with on L2
   * @param _minGasLimitSetBurnAmount Minimum gas limit that the message can be executed with to set the burn amount
   */
  function migrateToNative(
    address _roleCaller,
    address _burnCaller,
    uint32 _minGasLimitReceiveOnL2,
    uint32 _minGasLimitSetBurnAmount
  ) external onlyOwner {
    // Leave this flow open to resend upgrading flow incase message fails on L2
    // Circle's USDC implementation of `transferOwnership` reverts on address(0)
    if (_roleCaller == address(0) || _burnCaller == address(0)) revert IOpUSDCBridgeAdapter_InvalidAddress();

    // Ensure messaging is enabled
    if (messengerStatus != Status.Active && messengerStatus != Status.Upgrading) {
      revert IOpUSDCBridgeAdapter_MessagingDisabled();
    }

    burnCaller = _burnCaller;
    messengerStatus = Status.Upgrading;

    ICrossDomainMessenger(MESSENGER).sendMessage(
      LINKED_ADAPTER,
      abi.encodeWithSignature('receiveMigrateToNative(address,uint32)', _roleCaller, _minGasLimitSetBurnAmount),
      _minGasLimitReceiveOnL2
    );

    emit MigratingToNative(MESSENGER, _burnCaller);
  }

  /**
   * @notice Sets the amount of USDC tokens that will be burned when the burnLockedUSDC function is called
   * @param _amount The amount of USDC tokens that will be burned
   * @dev Only callable by a whitelisted messenger during its migration process
   */
  function setBurnAmount(uint256 _amount) external checkSender {
    if (messengerStatus != Status.Upgrading) revert IOpUSDCBridgeAdapter_NotUpgrading();

    burnAmount = _amount;
    messengerStatus = Status.Deprecated;

    emit BurnAmountSet(_amount);
  }

  /**
   * @notice Burns the USDC tokens locked in the contract
   * @dev The amount is determined by the burnAmount variable, which is set in the setBurnAmount function
   */
  function burnLockedUSDC() external {
    // NOTE: Does this need to be the roleCaller? Or the new owner?
    if (msg.sender != burnCaller) revert IOpUSDCBridgeAdapter_InvalidSender();

    // If the adapter is not deprecated the burn amount has not been set
    if (messengerStatus != Status.Deprecated) revert IOpUSDCBridgeAdapter_BurnAmountNotSet();

    // Burn the USDC tokens
    if (burnAmount != 0) {
      IUSDC(USDC).burn(burnAmount);

      // Set the burn amount to 0
      burnAmount = 0;
    }

    burnCaller = address(0);

    emit MigrationComplete();
  }

  /*///////////////////////////////////////////////////////////////
                          MESSAGING CONTROL
  ///////////////////////////////////////////////////////////////*/

  /**
   * @notice Send a message to the linked adapter to call receiveStopMessaging() and stop outgoing messages.
   * @dev Only callable by the owner of the adapter
   * @dev Setting isMessagingDisabled to true is an irreversible operation
   * @param _minGasLimit Minimum gas limit that the message can be executed with
   */
  function stopMessaging(uint32 _minGasLimit) external onlyOwner {
    // Ensure messaging is enabled
    // If its paused we still leave this function open to be called incase the message fails on L2
    if (messengerStatus != Status.Active && messengerStatus != Status.Paused) {
      revert IOpUSDCBridgeAdapter_MessagingDisabled();
    }

    messengerStatus = Status.Paused;

    ICrossDomainMessenger(MESSENGER).sendMessage(
      LINKED_ADAPTER, abi.encodeWithSignature('receiveStopMessaging()'), _minGasLimit
    );

    emit MessagingStopped(MESSENGER);
  }

  /**
   * @notice Resume messaging on the messenger
   * @dev Only callable by the owner
   * @dev Cant resume deprecated or upgrading messengers
   * @param _minGasLimit Minimum gas limit that the message can be executed with
   */
  function resumeMessaging(uint32 _minGasLimit) external onlyOwner {
    // Ensure messaging is disabled
    // If its active we still leave this function open to be called incase the message fails on L2
    if (messengerStatus != Status.Paused && messengerStatus != Status.Active) {
      revert IOpUSDCBridgeAdapter_MessagingEnabled();
    }

    messengerStatus = Status.Active;

    ICrossDomainMessenger(MESSENGER).sendMessage(
      LINKED_ADAPTER, abi.encodeWithSignature('receiveResumeMessaging()'), _minGasLimit
    );

    emit MessagingResumed(MESSENGER);
  }

  /*///////////////////////////////////////////////////////////////
                             MESSAGING
  ///////////////////////////////////////////////////////////////*/

  /**
   * @notice Send tokens to other chain through the linked adapter
   * @param _to The target address on the destination chain
   * @param _amount The amount of tokens to send
   * @param _minGasLimit Minimum gas limit that the message can be executed with
   */
  function sendMessage(address _to, uint256 _amount, uint32 _minGasLimit) external override {
    // Ensure messaging is enabled
    if (messengerStatus != Status.Active) revert IOpUSDCBridgeAdapter_MessagingDisabled();

    // Transfer the tokens to the contract
    IUSDC(USDC).safeTransferFrom(msg.sender, address(this), _amount);

    // Send the message to the linked adapter
    ICrossDomainMessenger(MESSENGER).sendMessage(
      LINKED_ADAPTER, abi.encodeWithSignature('receiveMessage(address,uint256)', _to, _amount), _minGasLimit
    );

    emit MessageSent(msg.sender, _to, _amount, MESSENGER, _minGasLimit);
  }

  /**
   * @notice Send tokens to other chain through the linked adapter
   * @param _signer The address of the user sending the message
   * @param _to The target address on the destination chain
   * @param _amount The amount of tokens to send
   * @param _signature The signature of the user
   * @param _deadline The deadline for the message to be executed
   * @param _minGasLimit Minimum gas limit that the message can be executed with
   */
  function sendMessage(
    address _signer,
    address _to,
    uint256 _amount,
    bytes calldata _signature,
    uint256 _deadline,
    uint32 _minGasLimit
  ) external override {
    // Ensure messaging is enabled
    if (messengerStatus != Status.Active) revert IOpUSDCBridgeAdapter_MessagingDisabled();

    // Ensure the deadline has not passed
    if (block.timestamp > _deadline) revert IOpUSDCBridgeAdapter_MessageExpired();

    // Hash the message
    bytes32 _messageHash = keccak256(abi.encode(address(this), block.chainid, _to, _amount, userNonce[_signer]++));

    _checkSignature(_signer, _messageHash, _signature);

    // Transfer the tokens to the contract
    IUSDC(USDC).safeTransferFrom(_signer, address(this), _amount);

    // Send the message to the linked adapter
    ICrossDomainMessenger(MESSENGER).sendMessage(
      LINKED_ADAPTER, abi.encodeWithSignature('receiveMessage(address,uint256)', _to, _amount), _minGasLimit
    );

    emit MessageSent(_signer, _to, _amount, MESSENGER, _minGasLimit);
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
    emit MessageReceived(_user, _amount, MESSENGER);
  }
}
