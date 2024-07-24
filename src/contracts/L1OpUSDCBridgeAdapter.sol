// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {OpUSDCBridgeAdapter} from 'contracts/universal/OpUSDCBridgeAdapter.sol';
import {IL1OpUSDCBridgeAdapter} from 'interfaces/IL1OpUSDCBridgeAdapter.sol';
import {IL2OpUSDCBridgeAdapter} from 'interfaces/IL2OpUSDCBridgeAdapter.sol';
import {IOpUSDCBridgeAdapter} from 'interfaces/IOpUSDCBridgeAdapter.sol';
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

  /**
   * @notice Modifier to check if the sender is the linked adapter through the messenger
   */
  modifier onlyLinkedAdapter() {
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
   * @dev Migrating to native is irreversible and will deprecate these adapters
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
      abi.encodeCall(IL2OpUSDCBridgeAdapter.receiveMigrateToNative, (_roleCaller, _minGasLimitSetBurnAmount)),
      _minGasLimitReceiveOnL2
    );

    emit MigratingToNative(MESSENGER, _burnCaller);
  }

  /**
   * @notice Sets the amount of USDC tokens that will be burned when the burnLockedUSDC function is called
   * @param _amount The amount of USDC tokens that will be burned
   * @dev Only callable by a whitelisted messenger during its migration process
   */
  function setBurnAmount(uint256 _amount) external onlyLinkedAdapter {
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
    if (msg.sender != burnCaller) revert IOpUSDCBridgeAdapter_InvalidSender();

    // If the adapter is not deprecated the burn amount has not been set
    if (messengerStatus != Status.Deprecated) revert IOpUSDCBridgeAdapter_BurnAmountNotSet();

    // Burn the USDC tokens
    // NOTE: If in flight transactions fail due to user being blacklisted after migration
    // The funds will just be trapped in this contract as its deprecated
    // If the user is after unblacklisted, they will be able to withdraw their usdc
    uint256 _burnAmount = burnAmount;
    if (_burnAmount != 0) {
      // NOTE: This is a very edge case and will only happen if the chain operator adds a second minter on L2
      // So now this adapter doesnt have the full backing supply locked in this contract
      // Incase the bridged usdc token has other minters and the supply sent is greater then what we have
      // We need to burn the full amount stored in this contract
      // This could also cause in-flight messages to fail because of the multiple supply sources
      uint256 _balanceOf = IUSDC(USDC).balanceOf(address(this));
      _burnAmount = _burnAmount > _balanceOf ? _balanceOf : _burnAmount;

      IUSDC(USDC).burn(_burnAmount);

      // Set the burn amount to 0
      burnAmount = 0;
    }

    burnCaller = address(0);
    emit MigrationComplete(_burnAmount);
  }

  /*///////////////////////////////////////////////////////////////
                          ADMIN CONTROL
  ///////////////////////////////////////////////////////////////*/

  /**
   * @notice Send a message to the linked adapter to call receiveStopMessaging() and stop outgoing messages.
   * @dev Only callable by the owner of the adapter
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
      LINKED_ADAPTER, abi.encodeCall(IL2OpUSDCBridgeAdapter.receiveStopMessaging, ()), _minGasLimit
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
      LINKED_ADAPTER, abi.encodeCall(IL2OpUSDCBridgeAdapter.receiveResumeMessaging, ()), _minGasLimit
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
    // Ensure the address is not blacklisted
    if (IUSDC(USDC).isBlacklisted(_to)) revert IOpUSDCBridgeAdapter_BlacklistedAddress();

    // Ensure messaging is enabled
    if (messengerStatus != Status.Active) revert IOpUSDCBridgeAdapter_MessagingDisabled();

    _sendMessage(msg.sender, _to, _amount, _minGasLimit);
  }

  /**
   * @notice Send signer tokens to other chain through the linked adapter
   * @param _signer The address of the user sending the message
   * @param _to The target address on the destination chain
   * @param _amount The amount of tokens to send
   * @param _signature The signature of the user
   * @param _nonce The nonce of the user
   * @param _deadline The deadline for the message to be executed
   * @param _minGasLimit Minimum gas limit that the message can be executed with
   */
  function sendMessage(
    address _signer,
    address _to,
    uint256 _amount,
    bytes calldata _signature,
    uint256 _nonce,
    uint256 _deadline,
    uint32 _minGasLimit
  ) external override {
    // Ensure the address is not blacklisted
    if (IUSDC(USDC).isBlacklisted(_to)) revert IOpUSDCBridgeAdapter_BlacklistedAddress();

    // Ensure messaging is enabled
    if (messengerStatus != Status.Active) revert IOpUSDCBridgeAdapter_MessagingDisabled();

    // Ensure the nonce has not already been used
    if (userNonces[_signer][_nonce]) revert IOpUSDCBridgeAdapter_InvalidNonce();

    // Ensure the deadline has not passed
    if (block.timestamp > _deadline) revert IOpUSDCBridgeAdapter_MessageExpired();

    // Hash the message
    bytes32 _messageHash =
      keccak256(abi.encode(address(this), block.chainid, _to, _amount, _deadline, _minGasLimit, _nonce));

    _checkSignature(_signer, _messageHash, _signature);

    // Mark the nonce as used
    userNonces[_signer][_nonce] = true;

    _sendMessage(_signer, _to, _amount, _minGasLimit);
  }

  /**
   * @notice Receive the message from the other chain and transfer the tokens to the user
   * @dev This function should only be called when receiving a message to transfer the tokens
   * @param _user The user to transfer the tokens to
   * @param _amount The amount of tokens to transfer
   */
  function receiveMessage(address _user, uint256 _amount) external override onlyLinkedAdapter {
    // Transfer the tokens to the user
    try this.attemptTransfer(_user, _amount) {
      emit MessageReceived(_user, _amount, MESSENGER);
    } catch {
      userBlacklistedFunds[_user] += _amount;
      emit MessageFailed(_user, _amount);
    }
  }

  /**
   * @notice Withdraws the blacklisted funds from the contract incase they get unblacklisted
   * @param _user The user to withdraw the funds for
   */
  function withdrawBlacklistedFunds(address _user) external override {
    uint256 _amount = userBlacklistedFunds[_user];
    userBlacklistedFunds[_user] = 0;

    // The check for if the user is blacklisted happens in USDC's contract
    IUSDC(USDC).safeTransfer(_user, _amount);

    emit BlacklistedFundsWithdrawn(_user, _amount);
  }

  /**
   * @notice Attempts to transfer the tokens to the user
   * @param _to The target address on the destination chain
   * @param _amount The amount of tokens to send
   * @dev This function should only be called when receiving a message
   * And is a workaround for the fact that try/catch
   * Only works on external calls and SafeERC20 is an internal library
   */
  function attemptTransfer(address _to, uint256 _amount) external {
    if (msg.sender != address(this)) revert IOpUSDCBridgeAdapter_InvalidSender();
    IUSDC(USDC).safeTransfer(_to, _amount);
  }

  /*///////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
  ///////////////////////////////////////////////////////////////*/
  function _sendMessage(address _from, address _to, uint256 _amount, uint32 _minGasLimit) internal {
    // Transfer the tokens to the contract
    IUSDC(USDC).safeTransferFrom(_from, address(this), _amount);

    // Send the message to the linked adapter
    ICrossDomainMessenger(MESSENGER).sendMessage(
      LINKED_ADAPTER, abi.encodeCall(IOpUSDCBridgeAdapter.receiveMessage, (_to, _amount)), _minGasLimit
    );

    emit MessageSent(_from, _to, _amount, MESSENGER, _minGasLimit);
  }
}
