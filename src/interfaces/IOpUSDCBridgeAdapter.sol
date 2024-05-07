// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IOpUSDCBridgeAdapter {
  /*///////////////////////////////////////////////////////////////
                            EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when the linked adapter is set
   * @param _linkedAdapter Address of the linked adapter
   */
  event LinkedAdapterSet(address _linkedAdapter);

  /**
   * @notice Emitted when messaging is stopped
   */
  event MessagingStopped();

  /**
   * @notice Emitted when a message is sent to the linked adapter
   * @param _user The user that sent the message
   * @param _amount The amount of tokens to send
   * @param _minGasLimit Minimum gas limit that the message can be executed with
   */
  event MessageSent(address _user, uint256 _amount, uint32 _minGasLimit);

  /**
   * @notice Emitted when a message as recieved
   * @param _user The user that recieved the message
   * @param _amount The amount of tokens recieved
   */
  event MessageReceived(address _user, uint256 _amount);

  /*///////////////////////////////////////////////////////////////
                            ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Error when messaging is disabled
   */
  error IOpUSDCBridgeAdapter_MessagingDisabled();

  /**
   * @notice Error when the caller is not the linked adapter
   */
  error IOpUSDCBridgeAdapter_NotLinkedAdapter();

  /**
   * @notice Error when a message is trying to be sent when linked adapter is not set
   */
  error IOpUSDCBridgeAdapter_LinkedAdapterNotSet();

  /*///////////////////////////////////////////////////////////////
                            VARIABLES
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Fetches address of the USDC token
   * @return _usdc Address of the USDC token
   */
  function USDC() external view returns (address _usdc);

  /**
   * @notice Fetches address of the CrossDomainMessenger to send messages to L1 <-> L2
   * @return _messenger Address of the messenger
   */
  function MESSENGER() external view returns (address _messenger);

  /**
   * @notice Fetches address of the linked adapter on L2 to send messages to and receive from
   * @return _linkedAdapter Address of the linked adapter
   */
  function linkedAdapter() external view returns (address _linkedAdapter);

  /**
   * @notice Fetches whether messaging is disabled
   * @return _isMessagingDisabled Whether messaging is disabled
   */
  function isMessagingDisabled() external view returns (bool _isMessagingDisabled);

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Set the linked adapter
   * @dev Only the owner can call this function
   * @param _linkedAdapter The address of the linked adapter
   */
  function setLinkedAdapter(address _linkedAdapter) external;

  /**
   * @notice Send the message to the linked adapter to mint the bridged representation on the linked chain
   * @param _amount The amount of tokens to send
   * @param _minGasLimit Minimum gas limit that the message can be executed with
   */
  function send(uint256 _amount, uint32 _minGasLimit) external;

  /**
   * @notice Receive the message from the other chain and mint the bridged representation for the user
   * @dev This function should only be called when receiving a message to mint the bridged representation
   * @param _user The user to mint the bridged representation for
   * @param _amount The amount of tokens to mint
   */
  function receiveMessage(address _user, uint256 _amount) external;

  /**
   * @notice Send a message to the linked adapter to call receiveStopMessaging() and stop outgoing messages.
   * @dev Only callable by the owner of the adapter.
   */
  function stopMessaging(uint32 _minGasLimit) external;

  /**
   * @notice Receive the stop messaging message from the linked adapter and stop outgoing messages
   */
  function receiveStopMessaging() external;
}
