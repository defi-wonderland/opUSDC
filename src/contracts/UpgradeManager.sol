// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import {IL1OpUSDCBridgeAdapter} from 'interfaces/IL1OpUSDCBridgeAdapter.sol';
import {IUpgradeManager} from 'interfaces/IUpgradeManager.sol';

contract UpgradeManager is IUpgradeManager, Initializable, OwnableUpgradeable, UUPSUpgradeable {
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
   * @param _circle The address to transfer ownerships to
   * @param _executor The address that will execute this migration
   */
  function prepareMigrateToNative(address _l1Messenger, address _circle, address _executor) external onlyOwner {
    if (migrations[_l1Messenger].executed) revert IUpgradeManager_MigrationAlreadyExecuted();

    migrations[_l1Messenger] = Migration(_circle, _executor, false);

    emit MigrationPrepared(_l1Messenger, _circle, _executor);
  }

  /**
   * @notice Execute the migration of the L1 Adapter to the native chain
   * @param _l1Messenger The address of the L1 messenger
   */
  function executeMigration(address _l1Messenger) external {
    Migration memory migration = migrations[_l1Messenger];

    // Check the migration is prepared, not executed and is being called by the executor
    if (migration.circle == address(0) || migration.executor == address(0)) {
      revert IUpgradeManager_MigrationNotPrepared();
    }
    if (migration.executed) revert IUpgradeManager_MigrationAlreadyExecuted();
    if (msg.sender != migration.executor) revert IUpgradeManager_NotExecutor();

    // Migrate
    IL1OpUSDCBridgeAdapter(L1_ADAPTER).migrateToNative(_l1Messenger, migration.circle);

    migrations[_l1Messenger].executed = true;

    emit MigrationExecuted(_l1Messenger, migration.circle, migration.executor);
  }

  /**
   * @notice Authorize the upgrade of the implementation of the contract
   * @param _newImplementation The address of the new implementation
   */
  function _authorizeUpgrade(address _newImplementation) internal override onlyOwner {}
}
