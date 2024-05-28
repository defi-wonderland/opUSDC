// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IL1OpUSDCBridgeAdapter {
  /*///////////////////////////////////////////////////////////////
                            ENUMS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice The status of an L1 Messenger
   * @param Uninitialized  The messenger is Uninitialized
   * @param Active The messenger is active
   * @param Paused The messenger is paused
   * @param Upgrading The messenger is upgrading
   * @param Deprecated The messenger is deprecated
   */
  enum Status {
    Uninitialized,
    Active,
    Paused,
    Upgrading,
    Deprecated
  }

  /*///////////////////////////////////////////////////////////////
                            EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when the burn amount is set
   * @param _burnAmount The amount to be burned
   */
  event BurnAmountSet(uint256 _burnAmount);

  /**
   * @notice Emitted when L2 upgrade method is called
   * @param _newImplementation The address of the new implementation
   * @param _messenger The address of the messenger
   * @param _data The data to be sent to the new implementation
   * @param _minGasLimit The minimum gas limit for the message
   */
  event L2AdapterUpgradeSent(address _newImplementation, address _messenger, bytes _data, uint32 _minGasLimit);

  /**
   * @notice Emitted when a new messenger is initialized
   * @param _messenger The address of the messenger
   */
  event MessengerInitialized(address _messenger);

  /*///////////////////////////////////////////////////////////////
                            ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Error when the the messenger is already initialized
   */
  error IL1OpUSDCBridgeAdapter_MessengerAlreadyInitialized();

  /**
   * @notice Error when the messenger is not paused
   */
  error IL1OpUSDCBridgeAdapter_MessengerNotPaused();

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Burns the USDC tokens locked in the contract
   * @dev The amount is determined by the burnAmount variable, which is set in the setBurnAmount function
   */
  function burnLockedUSDC() external;

  /**
   * @notice Sets the amount of USDC tokens that will be burned when the burnLockedUSDC function is called
   * @param _amount The amount of USDC tokens that will be burned
   * @dev Only callable by a whitelisted messenger during its migration process
   */
  function setBurnAmount(uint256 _amount) external;

  /**
   * @notice Send a message to the linked adapter to call receiveStopMessaging() and stop outgoing messages.
   * @dev Only callable by the owner of the adapter
   * @dev Setting isMessagingDisabled to true is an irreversible operation
   * @param _messenger The address of the L2 messenger to stop messaging with
   * @param _minGasLimit Minimum gas limit that the message can be executed with
   */
  function stopMessaging(address _messenger, uint32 _minGasLimit) external;

  /**
   * @notice Resume messaging on the messenger
   * @dev Only callable by the UpgradeManager
   * @dev Cant resume deprecated messengers
   * @param _messenger The address of the messenger to resume
   * @param _minGasLimit Minimum gas limit that the message can be executed with
   */
  function resumeMessaging(address _messenger, uint32 _minGasLimit) external;

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
  ) external;

  /**
   * @notice Send the message to the linked adapter to mint the bridged representation on the linked chain
   * @param _to The target address on the destination chain
   * @param _amount The amount of tokens to send
   * @param _messenger The address of the messenger contract to send through
   * @param _minGasLimit Minimum gas limit that the message can be executed with
   */
  function sendMessage(address _to, uint256 _amount, address _messenger, uint32 _minGasLimit) external;

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
  ) external;

  /*///////////////////////////////////////////////////////////////
                            VARIABLES
  //////////////////////////////////////////////////////////////*/

  /**
   * @return _upgradeManager The address of the Upgrade Manager contract
   */
  // solhint-disable-next-line func-name-mixedcase
  function UPGRADE_MANAGER() external view returns (address _upgradeManager);

  /**
   * @return _factory The address of the factory contract
   */
  // solhint-disable-next-line func-name-mixedcase
  function FACTORY() external view returns (address _factory);

  /**
   * @notice Fetches the amount of USDC tokens that will be burned when the burnLockedUSDC function is called
   * @return _burnAmount The amount of USDC tokens that will be burned
   */
  function burnAmount() external view returns (uint256 _burnAmount);

  /**
   * @notice Fetches the address of the Circle contract
   * @return _circle The address of the Circle contract
   */
  function circle() external view returns (address _circle);

  /**
   * @notice Fetches the status of an L1 messenger
   * @param _l1Messenger The address of the L1 messenger
   * @return _status The status of the messenger
   */
  function messengerStatus(address _l1Messenger) external view returns (Status _status);
}
