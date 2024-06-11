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

  /**
   * @notice USDC function signatures
   */
  bytes4 internal constant _TRANSFER_OWNERSHIP = 0xf2fde38b;
  bytes4 internal constant _UPGRADE_TO = 0x3659cfe6;
  bytes4 internal constant _UPGRADE_TO_AND_CALL = 0x4f1ef286;
  bytes4 internal constant _CHANGE_ADMIN = 0x8f283970;

  /// @inheritdoc IL1OpUSDCBridgeAdapter
  uint256 public burnAmount;

  /// @inheritdoc IL1OpUSDCBridgeAdapter
  address public circle;

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
  ) OpUSDCBridgeAdapter(_usdc, _messenger, _linkedAdapter) Ownable(_owner) {}

  /*///////////////////////////////////////////////////////////////
                              MIGRATION
  ///////////////////////////////////////////////////////////////*/

  /**
   * @notice Initiates the process to migrate the bridged USDC to native USDC
   * @param _circle The address to transfer ownerships to
   * @param _minGasLimitReceiveOnL2 Minimum gas limit that the message can be executed with on L2
   * @param _minGasLimitSetBurnAmount Minimum gas limit that the message can be executed with to set the burn amount
   */
  function migrateToNative(
    address _circle,
    uint32 _minGasLimitReceiveOnL2,
    uint32 _minGasLimitSetBurnAmount
  ) external onlyOwner {
    // Leave this flow open to resend upgrading flow incase message fails on L2

    // Circle implementation of `transferOwnership` reverts on address(0)
    if (_circle == address(0)) revert IL1OpUSDCBridgeAdapter_InvalidAddress();

    // Ensure messaging is enabled
    if (messengerStatus != Status.Active && messengerStatus != Status.Upgrading) {
      revert IOpUSDCBridgeAdapter_MessagingDisabled();
    }

    circle = _circle;
    messengerStatus = Status.Upgrading;

    ICrossDomainMessenger(MESSENGER).sendMessage(
      LINKED_ADAPTER,
      abi.encodeWithSignature('receiveMigrateToNative(address,uint32)', _circle, _minGasLimitSetBurnAmount),
      _minGasLimitReceiveOnL2
    );

    emit MigratingToNative(MESSENGER, _circle);
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
    if (msg.sender != circle) revert IOpUSDCBridgeAdapter_InvalidSender();

    // Burn the USDC tokens
    IUSDC(USDC).burn(address(this), burnAmount);

    // Set the burn amount to 0
    burnAmount = 0;
    circle = address(0);

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
    if (messengerStatus != Status.Active) revert IOpUSDCBridgeAdapter_MessagingDisabled();

    messengerStatus = Status.Paused;

    ICrossDomainMessenger(MESSENGER).sendMessage(
      LINKED_ADAPTER, abi.encodeWithSignature('receiveStopMessaging()'), _minGasLimit
    );

    emit MessagingStopped(MESSENGER);
  }

  /**
   * @notice Resume messaging on the messenger
   * @dev Only callable by the owner
   * @dev Cant resume deprecated messengers
   * @param _minGasLimit Minimum gas limit that the message can be executed with
   */
  function resumeMessaging(uint32 _minGasLimit) external onlyOwner {
    // Ensure messaging is disabled
    if (messengerStatus != Status.Paused) revert IOpUSDCBridgeAdapter_MessagingEnabled();

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

  /*///////////////////////////////////////////////////////////////
                        BRIDGED USDC FUNCTIONS
  ///////////////////////////////////////////////////////////////*/
  /**
   * @notice Send a message from the owner to execute a call with abitrary calldata on USDC contract.
   * @dev can't execute the following list of transactions:
   *  • transferOwnership (0xf2fde38b)
   *  • upgradeTo (0x3659cfe6)
   *  • upgradeToAndCall (0x4f1ef286)
   *  • changeAdmin (0x8f283970)
   */
  function sendUsdcOwnableFunction(bytes calldata _data, uint32 _minGasLimit) external onlyOwner {
    // Ensure adapter is not deprecated allowing owner messages even when messaging is disabled
    // since owner messages are used to execute transactions on the USDC contract.
    if (messengerStatus == Status.Deprecated) revert IOpUSDCBridgeAdapter_MessagingDisabled();

    if (_data.length < 4) revert IL1OpUSDCBridgeAdapter_InvalidCalldata();

    //Check forbidden transactions
    bytes4 _signature = bytes4(_data[:4]);
    if (
      _signature == _TRANSFER_OWNERSHIP || _signature == _UPGRADE_TO || _signature == _UPGRADE_TO_AND_CALL
        || _signature == _CHANGE_ADMIN
    ) revert IL1OpUSDCBridgeAdapter_ForbiddenTransaction();

    // Send the message to the linked adapter
    ICrossDomainMessenger(MESSENGER).sendMessage(
      LINKED_ADAPTER, abi.encodeWithSignature('receiveUsdcOwnableFunction(bytes)', _data), _minGasLimit
    );

    emit UsdcOwnableFunctionSent(_signature, _minGasLimit);
  }

  /**
   * @notice Send a message to the linked adapter to upgrade the implementation of the USDC contract
   * @param _implTxs The transactions to initialize the new implementation
   * @param _proxyTxs The transactions to initialize the proxy contract
   * @param _minGasLimit Minimum gas limit that the message can be executed with
   */
  function sendUsdcUpgrade(bytes[] memory _implTxs, bytes[] memory _proxyTxs, uint32 _minGasLimit) external onlyOwner {
    // Ensure messaging is enabled
    if (messengerStatus != Status.Active) revert IOpUSDCBridgeAdapter_MessagingDisabled();

    // Get the bytecode of the USDC current implementation
    address _usdcImplementation = IUSDC(USDC).implementation();

    ICrossDomainMessenger(MESSENGER).sendMessage(
      LINKED_ADAPTER,
      abi.encodeWithSignature(
        'receiveUsdcUpgrade(bytes,bytes[],bytes[])', _usdcImplementation.code, _implTxs, _proxyTxs
      ),
      _minGasLimit
    );

    emit UsdcUpgradeSent(_usdcImplementation, MESSENGER, _minGasLimit);
  }
}
