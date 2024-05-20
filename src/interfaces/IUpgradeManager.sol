// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IUpgradeManager {
  // NOTE: Style guide says structs go under errors, but linter was complaining, which is correct?

  /*///////////////////////////////////////////////////////////////
                            STRUCTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice The values used for a migration
   * @param circle The address to transfer ownerships to
   * @param executor The address of the executor
   * @param executed Whether the migration has been executed
   */
  struct Migration {
    address circle;
    address executor;
    bool executed;
  }

  /*///////////////////////////////////////////////////////////////
                            EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when a migration is prepared
   */
  event MigrationPrepared(address indexed l1Messenger, address indexed circle, address indexed executor);

  /**
   * @notice Emitted when a migration is executed
   */
  event MigrationExecuted(address indexed l1Messenger, address indexed circle, address indexed executor);

  /**
   * @notice Emitted when an L1 Adapter Implementation is set
   */
  event L1AdapterImplementationSet(address indexed implementation);

  /**
   * @notice Emitted when an L2 Adapter Implementation is set
   */
  event L2AdapterImplementationSet(address indexed implementation);

  /**
   * @notice Emitted when a Bridged USDC Implementation is set
   */
  event BridgedUSDCImplementationSet(address indexed implementation);

  /**
   * @notice Emitted when an L1 Messenger is whitelisted
   */
  event MessengerWhitelisted(address l1Messenger);

  /*///////////////////////////////////////////////////////////////
                            ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Error when the migration is not prepared
   */
  error IUpgradeManager_MigrationNotPrepared();

  /**
   * @notice Error when the migration is already executed
   */
  error IUpgradeManager_MigrationAlreadyExecuted();

  /**
   * @notice Error when the caller is not the executor
   */
  error IUpgradeManager_NotExecutor();

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Set the implementation of the L2 Adapter
   * @dev Only callable by the owner
   * @param _newImplementation The address of the new implementation
   */
  function setL2AdapterImplementation(address _newImplementation) external;

  /**
   * @notice Set the implementation of the Bridged USDC token
   * @dev Only callable by the owner
   * @param _newImplementation The address of the new implementation
   */
  function setBridgedUSDCImplementation(address _newImplementation) external;

  /**
   * @notice Prepare the migration of the L1 Adapter to the native chain
   * @param _l1Messenger The address of the L1 messenger
   * @param _circle The address to transfer ownerships to
   * @param _executor The address that will execute this migration
   */
  function prepareMigrateToNative(address _l1Messenger, address _circle, address _executor) external;

  /**
   * @notice Execute the migration of the L1 Adapter to the native chain
   * @param _l1Messenger The address of the L1 messenger
   */
  function executeMigration(address _l1Messenger) external;

  /*///////////////////////////////////////////////////////////////
                            VARIABLES
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Fetches the address of the L2 Adapter implementation
   * @return _implementation The address of the L2 Adapter implementation
   */
  function l2AdapterImplementation() external view returns (address _implementation);

  /**
   * @notice Fetches the address of the Bridged USDC implementation
   * @return _implementation The address of the Bridged USDC implementation
   */
  function bridgedUSDCImplementation() external view returns (address _implementation);

  /**
   * @notice Fetches the migration details for a given L1 Messenger
   * @param _l1Messenger The address of the L1 Messenger
   * @return _circle The address to transfer ownerships to
   * @return _executor The address of the executor
   * @return _executed Whether the migration has been executed
   */
  function migrations(address _l1Messenger) external view returns (address _circle, address _executor, bool _executed);

  /**
   * @notice Checks if an L1 Messenger is whitelisted
   * @param _l1Messenger The address of the L1 Messenger
   */
  function isL1MessengerWhitelisted(address _l1Messenger) external view returns (bool);

  /**
   * @notice Fetches the address of the L1 Adapter
   * @return _l1Adapter The address of the adapter
   */
  // solhint-disable-next-line func-name-mixedcase
  function L1_ADAPTER() external view returns (address _l1Adapter);
}
