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

  /// @inheritdoc IUpgradeManager
  address public l2AdapterImplementation;

  /// @inheritdoc IUpgradeManager
  address public bridgedUSDCImplementation;

  /// @inheritdoc IUpgradeManager
  mapping(address _l1Messenger => Migration migration) public migrations;

  /// @inheritdoc IUpgradeManager
  mapping(address _l1Messenger => bool isWhitelisted) public isL1MessengerWhitelisted;

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
   * @param _newImplementation The address of the new implementation
   */
  function setL2AdapterImplementation(address _newImplementation) external onlyOwner {
    l2AdapterImplementation = _newImplementation;

    emit L2AdapterImplementationSet(_newImplementation);
  }

  /**
   * @notice Set the implementation of the Bridged USDC token
   * @dev Only callable by the owner
   * @param _newImplementation The address of the new implementation
   */
  function setBridgedUSDCImplementation(address _newImplementation) external onlyOwner {
    bridgedUSDCImplementation = _newImplementation;

    emit BridgedUSDCImplementationSet(_newImplementation);
  }

  /**
   * @notice Whitelist an L1 Messenger
   * @param _l1Messenger The address of the L1 Messenger
   */
  function whitelistMessenger(address _l1Messenger) external onlyOwner {
    isL1MessengerWhitelisted[_l1Messenger] = true;

    emit MessengerWhitelisted(_l1Messenger);
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
    IL1OpUSDCBridgeAdapter(L1_ADAPTER).stopMessaging(_minGasLimit, _messenger);
  }

  /**
   * @notice Execute the migration of the L1 Adapter to the native chain
   * @param _l1Messenger The address of the L1 messenger
   */
  function executeMigration(address _l1Messenger) external {
    Migration memory _migration = migrations[_l1Messenger];

    // Check the migration is prepared, not executed and is being called by the executor
    if (_migration.circle == address(0) || _migration.executor == address(0)) {
      revert IUpgradeManager_MigrationNotPrepared();
    }
    if (_migration.executed) revert IUpgradeManager_MigrationAlreadyExecuted();
    if (msg.sender != _migration.executor) revert IUpgradeManager_NotExecutor();

    // Migrate
    IL1OpUSDCBridgeAdapter(L1_ADAPTER).migrateToNative(_l1Messenger, _migration.circle);

    migrations[_l1Messenger].executed = true;

    emit MigrationExecuted(_l1Messenger, _migration.circle, _migration.executor);
  }

  /**
   * @notice Authorize the upgrade of the implementation of the contract
   * @param _newImplementation The address of the new implementation
   */
  function _authorizeUpgrade(address _newImplementation) internal override onlyOwner {}
}
