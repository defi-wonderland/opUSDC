// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import {IL1OpUSDCBridgeAdapter} from 'interfaces/IL1OpUSDCBridgeAdapter.sol';
import {IUpgradeManager} from 'interfaces/IUpgradeManager.sol';

/**
 * @notice The UpgradeManager contract
 * @title UpgradeManager
 */
contract UpgradeManager is Initializable, OwnableUpgradeable, UUPSUpgradeable, IUpgradeManager {
  /// @inheritdoc IUpgradeManager
  address public immutable L1_ADAPTER;

  /// @notice The address and initialization transactions of the L2 Adapter implementation
  Implementation internal _l2AdapterImplementation;

  /// @notice The address and initialization transactions of the Bridged USDC implementation
  Implementation internal _bridgedUSDCImplementation;

  /// @inheritdoc IUpgradeManager
  mapping(address _l1Messenger => Migration migration) public migrations;

  /// @inheritdoc IUpgradeManager
  mapping(address _l1Messenger => address _executor) public messengerDeploymentExecutor;

  /**
   * @notice Construct the UpgradeManager contract
   * @param _l1Adapter The address of the L1 Adapter
   */
  constructor(address _l1Adapter) {
    L1_ADAPTER = _l1Adapter;
    _disableInitializers();
  }

  /**
   * @notice Initialize the contract
   * @param _initialOwner The address of the initial owner of the contract
   */
  function initialize(address _initialOwner) external initializer {
    __Ownable_init(_initialOwner);
  }

  /**
   * @notice Set the implementation of the L2 Adapter
   * @dev Only callable by the owner
   * @param _newImplementation The address of the new L2 adapter implementation
   * @param _initTxs The transactions to run on the deployed implementation
   */
  function setL2AdapterImplementation(address _newImplementation, bytes[] memory _initTxs) external onlyOwner {
    _l2AdapterImplementation.implementation = _newImplementation;
    _l2AdapterImplementation.initTxs = _initTxs;

    emit L2AdapterImplementationSet(_newImplementation);
  }

  /**
   * @notice Set the implementation of the Bridged USDC token
   * @dev Only callable by the owner
   * @param _newImplementation The address of the new L2 Bridged USDC implementation
   * @param _initTxs The transactions to run on the deployed implementation
   */
  function setBridgedUSDCImplementation(address _newImplementation, bytes[] memory _initTxs) external onlyOwner {
    _bridgedUSDCImplementation.implementation = _newImplementation;
    _bridgedUSDCImplementation.initTxs = _initTxs;

    emit BridgedUSDCImplementationSet(_newImplementation);
  }

  /**
   * @notice Whitelist an L1 Messenger for deployment that must be called by executor
   * @param _l1Messenger The address of the L1 Messenger
   * @param _executor The address that will execute the deployment
   */
  function prepareDeploymentForMessenger(address _l1Messenger, address _executor) external onlyOwner {
    messengerDeploymentExecutor[_l1Messenger] = _executor;

    emit MessengerWhitelistedForDeployment(_l1Messenger, _executor);
  }

  /**
   * @notice Prepare the migration of the L1 Adapter to the native chain
   * @param _l1Messenger The address of the L1 messenger
   * @param _newOwner The address to transfer ownership to
   * @param _executor The address that will execute this migration
   */
  function prepareMigrateToNative(address _l1Messenger, address _newOwner, address _executor) external onlyOwner {
    if (migrations[_l1Messenger].executed) revert IUpgradeManager_MigrationAlreadyExecuted();

    migrations[_l1Messenger] = Migration(_newOwner, _executor, false);

    emit MigrationPrepared(_l1Messenger, _newOwner, _executor);
  }

  /**
   * @notice Resume messaging on the messenger
   * @dev Only callable by the UpgradeManager
   * @dev Cant resume deprecated messengers
   * @param _messenger The address of the messenger to resume
   * @param _minGasLimit Minimum gas limit that the message can be executed with
   */
  function resumeMessaging(address _messenger, uint32 _minGasLimit) external onlyOwner {
    IL1OpUSDCBridgeAdapter(L1_ADAPTER).resumeMessaging(_messenger, _minGasLimit);
  }

  /**
   * @notice Stop messaging on the messenger
   * @dev Only callable by the owner of the adapter.
   * @dev Setting isMessagingDisabled to true is an irreversible operation.
   * @param _minGasLimit Minimum gas limit that the message can be executed with
   * @param _messenger The address of the L2 messenger to stop messaging with
   */
  function stopMessaging(address _messenger, uint32 _minGasLimit) external onlyOwner {
    IL1OpUSDCBridgeAdapter(L1_ADAPTER).stopMessaging(_messenger, _minGasLimit);
  }

  /**
   * @notice Execute the migration of the L1 Adapter to the native chain
   * @param _l1Messenger The address of the L1 messenger
   * @param _minGasLimitReceiveOnL2 Minimum gas limit that the message can be executed with on L2
   * @param _minGasLimitSetBurnAmount Minimum gas limit that the message can be executed with to set the burn amount
   */
  function executeMigration(
    address _l1Messenger,
    uint32 _minGasLimitReceiveOnL2,
    uint32 _minGasLimitSetBurnAmount
  ) external {
    Migration memory _migration = migrations[_l1Messenger];

    // Check the migration is prepared, not executed and is being called by the executor
    if (_migration.circle == address(0) || _migration.executor == address(0)) {
      revert IUpgradeManager_MigrationNotPrepared();
    }
    if (_migration.executed) revert IUpgradeManager_MigrationAlreadyExecuted();
    if (msg.sender != _migration.executor) revert IUpgradeManager_NotExecutor();

    // Migrate
    IL1OpUSDCBridgeAdapter(L1_ADAPTER).migrateToNative(
      _migration.circle, _minGasLimitReceiveOnL2, _minGasLimitSetBurnAmount
    );

    migrations[_l1Messenger].executed = true;

    emit MigrationExecuted(_l1Messenger, _migration.circle, _migration.executor);
  }

  /**
   * @notice Get the implementation of the L2 Adapter
   * @return _implementation The address and initialization transactions of the L2 Adapter implementation
   */
  function l2AdapterImplementation() external view returns (Implementation memory _implementation) {
    _implementation = _l2AdapterImplementation;
  }

  /**
   * @notice Fetches the address of the Bridged USDC implementation
   * @return _implementation The address and initialization transactions of the L2 Bridged USDC implementation
   */
  function bridgedUSDCImplementation() external view returns (Implementation memory _implementation) {
    _implementation = _bridgedUSDCImplementation;
  }

  /**
   * @notice Authorize the upgrade of the implementation of the contract
   * @param _newImplementation The address of the new implementation
   */
  function _authorizeUpgrade(address _newImplementation) internal override onlyOwner {}
}
