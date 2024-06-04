// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {OpUSDCBridgeAdapter} from 'contracts/universal/OpUSDCBridgeAdapter.sol';
import {IL1OpUSDCBridgeAdapter} from 'interfaces/IL1OpUSDCBridgeAdapter.sol';
import {IUpgradeManager} from 'interfaces/IUpgradeManager.sol';
import {ICrossDomainMessenger} from 'interfaces/external/ICrossDomainMessenger.sol';
import {IUSDC} from 'interfaces/external/IUSDC.sol';

contract L1OpUSDCBridgeAdapter is OpUSDCBridgeAdapter, UUPSUpgradeable, IL1OpUSDCBridgeAdapter {
  using SafeERC20 for IUSDC;

  /// @inheritdoc IL1OpUSDCBridgeAdapter
  address public immutable UPGRADE_MANAGER;

  /// @inheritdoc IL1OpUSDCBridgeAdapter
  address public immutable FACTORY;

  /// @inheritdoc IL1OpUSDCBridgeAdapter
  uint256 public burnAmount;

  /// @inheritdoc IL1OpUSDCBridgeAdapter
  address public circle;

  /// @inheritdoc IL1OpUSDCBridgeAdapter
  mapping(address _l1Messenger => Status _status) public messengerStatus;

  /**
   * @notice modifier to check that the sender is the Upgrade Manager
   */
  modifier onlyUpgradeManager() {
    if (msg.sender != UPGRADE_MANAGER) revert IOpUSDCBridgeAdapter_InvalidSender();
    _;
  }

  /**
   * @notice Modifier to check if the sender is the linked adapter through the messenger
   */
  modifier checkSender() {
    // We should accept incoming messages from all messengers that have been initialized
    if (
      messengerStatus[msg.sender] != Status.Active
        || ICrossDomainMessenger(msg.sender).xDomainMessageSender() != LINKED_ADAPTER
    ) {
      revert IOpUSDCBridgeAdapter_InvalidSender();
    }
    _;
  }

  /**
   * @notice Construct the OpUSDCBridgeAdapter contract
   * @param _usdc The address of the USDC Contract to be used by the adapter
   * @param _linkedAdapter The address of the linked adapter
   * @param _upgradeManager The address of the upgrade manager
   * @param _factory The address of the factory
   * @dev The constructor is only used to initialize the OpUSDCBridgeAdapter immutable variables
   */
  /* solhint-disable no-unused-vars */
  constructor(
    address _usdc,
    address _linkedAdapter,
    address _upgradeManager,
    address _factory
  ) OpUSDCBridgeAdapter(_usdc, _linkedAdapter) {
    UPGRADE_MANAGER = _upgradeManager;
    FACTORY = _factory;
  }
  /* solhint-enable no-unused-vars */

  /**
   * @notice Sets the amount of USDC tokens that will be burned when the burnLockedUSDC function is called
   * @param _amount The amount of USDC tokens that will be burned
   * @dev Only callable by a whitelisted messenger during its migration process
   */
  function setBurnAmount(uint256 _amount) external {
    if (
      messengerStatus[msg.sender] != Status.Upgrading
        || ICrossDomainMessenger(msg.sender).xDomainMessageSender() != LINKED_ADAPTER
    ) {
      revert IOpUSDCBridgeAdapter_InvalidSender();
    }

    burnAmount = _amount;
    messengerStatus[msg.sender] = Status.Deprecated;

    emit BurnAmountSet(_amount);
  }

  /**
   * @notice Resume messaging on the messenger
   * @dev Only callable by the UpgradeManager
   * @dev Cant resume deprecated messengers
   * @param _messenger The address of the messenger to resume
   * @param _minGasLimit Minimum gas limit that the message can be executed with
   */
  function resumeMessaging(address _messenger, uint32 _minGasLimit) external onlyUpgradeManager {
    if (messengerStatus[_messenger] != Status.Paused) revert IL1OpUSDCBridgeAdapter_MessengerNotPaused();

    messengerStatus[_messenger] = Status.Active;

    ICrossDomainMessenger(_messenger).sendMessage(
      LINKED_ADAPTER, abi.encodeWithSignature('receiveResumeMessaging()'), _minGasLimit
    );

    emit MessagingResumed(_messenger);
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
  }

  /**
   * @notice Initialize a new messenger
   * @param _l1Messenger The address of the L1 messenger
   * @dev Only callable by the factory, will be called at deployment of the corresponding chains adapter
   */
  function initalizeNewMessenger(address _l1Messenger) external {
    if (msg.sender != FACTORY) revert IOpUSDCBridgeAdapter_InvalidSender();
    if (messengerStatus[_l1Messenger] != Status.Uninitialized) {
      revert IL1OpUSDCBridgeAdapter_MessengerAlreadyInitialized();
    }

    messengerStatus[_l1Messenger] = Status.Active;

    emit MessengerInitialized(_l1Messenger);
  }

  /**
   * @notice Send the message to the linked adapter to mint the bridged representation on the linked chain
   * @param _to The target address on the destination chain
   * @param _amount The amount of tokens to send
   * @param _messenger The address of the messenger contract to send through
   * @param _minGasLimit Minimum gas limit that the message can be executed with
   */
  function sendMessage(address _to, uint256 _amount, address _messenger, uint32 _minGasLimit) external {
    // Ensure messaging is enabled
    if (messengerStatus[_messenger] != Status.Active) revert IOpUSDCBridgeAdapter_MessagingDisabled();

    // Transfer the tokens to the contract
    IUSDC(USDC).safeTransferFrom(msg.sender, address(this), _amount);

    // Send the message to the linked adapter
    ICrossDomainMessenger(_messenger).sendMessage(
      LINKED_ADAPTER, abi.encodeWithSignature('receiveMessage(address,uint256)', _to, _amount), _minGasLimit
    );

    emit MessageSent(msg.sender, _to, _amount, _messenger, _minGasLimit);
  }

  /**
   * @notice Send the message to the linked adapter to mint the bridged representation on the linked chain
   * @param _signer The address of the user sending the message
   * @param _to The target address on the destination chain
   * @param _amount The amount of tokens to send
   * @param _messenger The address of the messenger contract to send through
   * @param _signature The signature of the user
   * @param _deadline The deadline for the message to be executed
   * @param _minGasLimit Minimum gas limit that the message can be executed with
   */
  function sendMessage(
    address _signer,
    address _to,
    uint256 _amount,
    address _messenger,
    bytes calldata _signature,
    uint256 _deadline,
    uint32 _minGasLimit
  ) external override {
    // Ensure messaging is enabled
    if (messengerStatus[_messenger] != Status.Active) revert IOpUSDCBridgeAdapter_MessagingDisabled();

    // Ensure the deadline has not passed
    if (block.timestamp > _deadline) revert IOpUSDCBridgeAdapter_MessageExpired();

    // Hash the message
    bytes32 _messageHash = keccak256(abi.encode(address(this), block.chainid, _to, _amount, userNonce[_signer]++));

    _checkSignature(_signer, _messageHash, _signature);

    // Transfer the tokens to the contract
    IUSDC(USDC).safeTransferFrom(_signer, address(this), _amount);

    // Send the message to the linked adapter
    ICrossDomainMessenger(_messenger).sendMessage(
      LINKED_ADAPTER, abi.encodeWithSignature('receiveMessage(address,uint256)', _to, _amount), _minGasLimit
    );

    emit MessageSent(_signer, _to, _amount, _messenger, _minGasLimit);
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

    emit MessageReceived(_user, _amount, msg.sender);
  }

  /**
   * @notice Initiates the process to migrate the bridged USDC to native USDC
   * @param _messenger The address of the L1 messenger
   * @param _circle The address to transfer ownerships to
   * @param _minGasLimitReceiveOnL2 Minimum gas limit that the message can be executed with on L2
   * @param _minGasLimitSetBurnAmount Minimum gas limit that the message can be executed with to set the burn amount
   */
  function migrateToNative(
    address _messenger,
    address _circle,
    uint32 _minGasLimitReceiveOnL2,
    uint32 _minGasLimitSetBurnAmount
  ) external onlyUpgradeManager {
    // Ensure messaging is enabled
    // Leave this flow open to resend upgrading flow incase message fails on L2
    if (messengerStatus[_messenger] != Status.Active && messengerStatus[_messenger] != Status.Upgrading) {
      revert IOpUSDCBridgeAdapter_MessagingDisabled();
    }
    if (circle != address(0) && messengerStatus[_messenger] != Status.Upgrading) {
      revert IOpUSDCBridgeAdapter_MigrationInProgress();
    }

    circle = _circle;
    messengerStatus[_messenger] = Status.Upgrading;

    ICrossDomainMessenger(_messenger).sendMessage(
      LINKED_ADAPTER,
      abi.encodeWithSignature('receiveMigrateToNative(address,uint32)', _circle, _minGasLimitSetBurnAmount),
      _minGasLimitReceiveOnL2
    );

    emit MigratingToNative(_messenger, _circle);
  }

  /**
   * @notice Send a message to the linked adapter to call receiveStopMessaging() and stop outgoing messages.
   * @dev Only callable by the owner of the adapter
   * @dev Setting isMessagingDisabled to true is an irreversible operation
   *  @param _messenger The address of the L2 messenger to stop messaging with
   * @param _minGasLimit Minimum gas limit that the message can be executed with
   */
  function stopMessaging(address _messenger, uint32 _minGasLimit) external onlyUpgradeManager {
    // Ensure messaging is enabled
    if (messengerStatus[_messenger] != Status.Active) revert IOpUSDCBridgeAdapter_MessagingDisabled();

    ICrossDomainMessenger(_messenger).sendMessage(
      LINKED_ADAPTER, abi.encodeWithSignature('receiveStopMessaging()'), _minGasLimit
    );

    messengerStatus[_messenger] = Status.Paused;

    emit MessagingStopped(_messenger);
  }

  /**
   * @notice Send a message to the linked adapter to upgrade the implementation of the contract
   * @param _messenger The address of the messenger contract to send through
   * @param _minGasLimit Minimum gas limit that the message can be executed with
   */
  function sendL2AdapterUpgrade(address _messenger, uint32 _minGasLimit) external {
    if (messengerStatus[_messenger] != Status.Active) revert IOpUSDCBridgeAdapter_MessagingDisabled();

    // Get the bytecode of the he L2 adapter
    IUpgradeManager.Implementation memory _l2AdapterImplementation =
      IUpgradeManager(UPGRADE_MANAGER).l2AdapterImplementation();
    bytes memory _l2AdapterBytecode = _l2AdapterImplementation.implementation.code;

    ICrossDomainMessenger(_messenger).sendMessage(
      LINKED_ADAPTER,
      abi.encodeWithSignature(
        'receiveAdapterUpgrade(bytes,bytes[])', _l2AdapterBytecode, _l2AdapterImplementation.initTxs
      ),
      _minGasLimit
    );

    emit L2AdapterUpgradeSent(_l2AdapterImplementation.implementation, _messenger, _minGasLimit);
  }

  /**
   * @notice Send a message to the linked adapter to upgrade the implementation of the USDC contract
   * @param _messenger The address of the messenger contract to send through
   * @param _minGasLimit Minimum gas limit that the message can be executed with
   */
  function sendL2UsdcUpgrade(address _messenger, uint32 _minGasLimit) external {
    if (messengerStatus[_messenger] != Status.Active) revert IOpUSDCBridgeAdapter_MessagingDisabled();

    // Get the bytecode of the he L2 adapter
    IUpgradeManager.Implementation memory _l2UsdcImplementation =
      IUpgradeManager(UPGRADE_MANAGER).bridgedUSDCImplementation();
    bytes memory _l2UsdcBytecode = _l2UsdcImplementation.implementation.code;

    ICrossDomainMessenger(_messenger).sendMessage(
      LINKED_ADAPTER,
      abi.encodeWithSignature('receiveUsdcUpgrade(bytes,bytes[])', _l2UsdcBytecode, _l2UsdcImplementation.initTxs),
      _minGasLimit
    );

    emit L2UsdcUpgradeSent(_l2UsdcImplementation.implementation, _messenger, _minGasLimit);
  }

  /**
   * @notice Authorize the upgrade of the implementation of the contract
   * @param _newImplementation The address of the new implementation
   */
  function _authorizeUpgrade(address _newImplementation) internal override onlyUpgradeManager {}
}
