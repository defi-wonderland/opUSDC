// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IOpUSDCBridgeAdapter {
  /*///////////////////////////////////////////////////////////////
                            EVENTS
  ///////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when messaging is stopped
   * @param _messenger The address of the messenger contract that was stopped
   */
  event MessagingStopped(address _messenger);

  /**
   * @notice Emitted when a message is sent to the linked adapter
   * @param _user The user that sent the message
   * @param _to The target address on the destination chain
   * @param _amount The amount of tokens to send
   * @param _messenger The address of the messenger contract that was sent through
   * @param _minGasLimit Minimum gas limit that the message can be executed with
   */
  event MessageSent(address _user, address _to, uint256 _amount, address _messenger, uint32 _minGasLimit);

  /**
   * @notice Emitted when a message as recieved
   * @param _user The user that recieved the message
   * @param _amount The amount of tokens recieved
   * @param _messenger The address of the messenger contract that was recieved through
   */
  event MessageReceived(address _user, uint256 _amount, address _messenger);

  /**
   * @notice Emitted when messaging is resumed
   * @param _messenger The address of the messenger that was resumed
   */
  event MessagingResumed(address _messenger);

  /**
   * @notice Emitted when the adapter is migrating usdc to native
   * @param _messenger The address of the messenger contract that is doing the migration
   * @param _caller The address that will be allowed to call the permissioned function on the given chain
   * @dev On L1 _caller can call burnLockedUSDC
   * @dev On L2 _caller can call transferUSDCRoles
   */
  event MigratingToNative(address _messenger, address _caller);

  /**
   * @notice Emitted when a message fails
   * @param _user The user that the message failed for
   * @param _amount The amount of tokens that were added to the blacklisted funds
   */
  event MessageFailed(address _user, uint256 _amount);

  /*///////////////////////////////////////////////////////////////
                            ERRORS
  ///////////////////////////////////////////////////////////////*/
  /**
   * @notice Error when burnLockedUSDC is called before a burn amount is set
   */
  error IOpUSDCBridgeAdapter_BurnAmountNotSet();

  /**
   * @notice Error when the caller is not the roleCaller
   */
  error IOpUSDCBridgeAdapter_InvalidCaller();

  /**
   * @notice Error when address is not valid
   */
  error IOpUSDCBridgeAdapter_InvalidAddress();

  /**
   * @notice Error when the owner transaction is invalid
   */
  error IOpUSDCBridgeAdapter_InvalidTransaction();

  /**
   * @notice Error when signature is not valid
   */
  error IOpUSDCBridgeAdapter_ForbiddenTransaction();

  /**
   * @notice Error when messaging is disabled
   */
  error IOpUSDCBridgeAdapter_MessagingDisabled();

  /**
   * @notice Error when messaging is enabled
   */
  error IOpUSDCBridgeAdapter_MessagingEnabled();

  /**
   * @notice Error when the caller is not the linked adapter
   */
  error IOpUSDCBridgeAdapter_InvalidSender();

  /**
   * @notice Error when the signature is invalid
   */
  error IOpUSDCBridgeAdapter_InvalidSignature();

  /**
   * @notice Error when the deadline has passed
   */
  error IOpUSDCBridgeAdapter_MessageExpired();

  /**
   * @notice Error when the contract is not in the upgrading state
   */
  error IOpUSDCBridgeAdapter_NotUpgrading();

  /**
   * @notice Error when the address is blacklisted
   */
  error IOpUSDCBridgeAdapter_BlacklistedAddress();

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  ///////////////////////////////////////////////////////////////*/
  /**
   * @notice Send tokens to other chain through the linked adapter
   * @param _to The target address on the destination chain
   * @param _amount The amount of tokens to send
   * @param _minGasLimit Minimum gas limit that the message can be executed with
   */
  function sendMessage(address _to, uint256 _amount, uint32 _minGasLimit) external;

  /**
   * @notice Send signer tokens to other chain through the linked adapter
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
  ) external;

  /**
   * @notice Receive the message from the other chain and mint the bridged representation for the user
   * @dev This function should only be called when receiving a message to mint the bridged representation
   * @param _user The user to mint the bridged representation for
   * @param _amount The amount of tokens to mint
   */
  function receiveMessage(address _user, uint256 _amount) external;

  /*///////////////////////////////////////////////////////////////
                            VARIABLES
  ///////////////////////////////////////////////////////////////*/

  /**
   * @notice Fetches address of the USDC token
   * @return _usdc Address of the USDC token
   */
  // solhint-disable-next-line func-name-mixedcase
  function USDC() external view returns (address _usdc);

  /**
   * @notice Fetches address of the linked adapter on L2 to send messages to and receive from
   * @return _linkedAdapter Address of the linked adapter
   */
  // solhint-disable-next-line func-name-mixedcase
  function LINKED_ADAPTER() external view returns (address _linkedAdapter);

  /**
   * @notice Fetches address of the CrossDomainMessenger to send messages to L1 <-> L2
   * @return _messenger Address of the messenger
   */
  // solhint-disable-next-line func-name-mixedcase
  function MESSENGER() external view returns (address _messenger);

  /**
   * @notice Returns the nonce of a given user to avoid replay attacks
   * @param _user The user to fetch the nonce for
   * @return _nonce The nonce of the user
   */
  function userNonce(address _user) external view returns (uint256 _nonce);

  /**
   * @notice Returns the amount of funds locked that got blacklisted
   * @return _amount The amount of funds locked from blacklisted messages
   */
  function blacklistedFunds() external view returns (uint256 _amount);
}
