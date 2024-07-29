// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IOpUSDCBridgeAdapter {
  /*///////////////////////////////////////////////////////////////
                            ENUMS
  ///////////////////////////////////////////////////////////////*/

  /**
   * @notice The status of an L1 Messenger
   * @param Active The messenger is active
   * @param Paused The messenger is paused
   * @param Upgrading The messenger is upgrading
   * @param Deprecated The messenger is deprecated
   */
  enum Status {
    Active,
    Paused,
    Upgrading,
    Deprecated
  }

  /*///////////////////////////////////////////////////////////////
                          STRUCTS
  ///////////////////////////////////////////////////////////////*/

  /**
   * @notice The struct to hold the data for a bridge message with signature
   * @param to The target address on the destination chain
   * @param amount The amount of tokens to send
   * @param deadline The deadline for the message to be executed
   * @param nonce The nonce of the user
   * @param minGasLimit The minimum gas limit for the message to be executed
   */
  struct BridgeMessage {
    address to;
    uint256 amount;
    uint256 deadline;
    uint256 nonce;
    uint32 minGasLimit;
  }

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
   * @param _spender The address that provided the tokens
   * @param _user The user that recieved the message
   * @param _amount The amount of tokens recieved
   * @param _messenger The address of the messenger contract that was recieved through
   */
  event MessageReceived(address _spender, address _user, uint256 _amount, address _messenger);

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
   * @param _spender The address that provided the tokens
   * @param _user The user that the message failed for
   * @param _amount The amount of tokens that were added to the blacklisted funds
   * @param _messenger The address of the messenger that the message failed for
   */
  event MessageFailed(address _spender, address _user, uint256 _amount, address _messenger);

  /**
   * @notice Emitted when the blacklisted funds are withdrawn
   * @param _user The user that the funds were withdrawn for
   * @param _amountWithdrawn The amount of tokens that were withdrawn
   */
  event BlacklistedFundsWithdrawn(address _user, uint256 _amountWithdrawn);

  /**
   * @notice Emitted when the blacklisted funds are sent back to L1
   * @param _spender The address that provided the tokens
   * @param _amountSent The amount of tokens that were withdrawn
   */
  event BlacklistedFundsSentBackToL1(address _spender, uint256 _amountSent);

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
   * @notice Error when the nonce is already used for the given signature
   */
  error IOpUSDCBridgeAdapter_InvalidNonce();

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

  /**
   *  @notice Error when bridgedUSDC has not been migrated yet to native USDC
   */
  error IOpUSDCBridgeAdapter_NotMigrated();

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
  ) external;

  /**
   * @notice Receive the message from the other chain and mint the bridged representation for the user
   * @dev This function should only be called when receiving a message to mint the bridged representation
   * @dev If the mint fails the funds might be recovered by calling withdrawBlacklistedFunds if the user
   *      is ever unblacklisted
   * @param _user The user to mint the bridged representation for
   * @param _spender The address that provided the tokens
   * @param _amount The amount of tokens to mint
   */
  function receiveMessage(address _user, address _spender, uint256 _amount) external;

  /**
   * @notice Withdraws the blacklisted funds from the contract if they get unblacklisted
   * @param _spender The address that provided the tokens
   * @param _user The user to withdraw the funds for
   */
  function withdrawBlacklistedFunds(address _spender, address _user) external;

  /**
   * @notice Cancels a signature by setting the nonce as used
   * @param _nonce The nonce of the signature to cancel
   */
  function cancelSignature(uint256 _nonce) external;

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
   * @notice Fetches the status of the messenger
   * @return _status The status of the messenger
   */
  function messengerStatus() external view returns (Status _status);

  /**
   * @notice Returns the nonce of a given user to avoid replay attacks
   * @param _user The user to check for
   * @param _nonce The nonce to check for
   * @return _used If the nonce has been used
   */
  function userNonces(address _user, uint256 _nonce) external view returns (bool _used);

  /**
   * @notice Returns the amount of funds locked that got blacklisted for a specific user
   * @param _spender The address that provided the tokens
   * @param _user The user to check for
   * @return _blacklistedAmount The amount of funds locked from blacklisted messages
   */
  function blacklistedFundsDetails(address _spender, address _user) external view returns (uint256 _blacklistedAmount);
}
