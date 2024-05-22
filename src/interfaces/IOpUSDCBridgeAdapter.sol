// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IOpUSDCBridgeAdapter {
  /*///////////////////////////////////////////////////////////////
                            EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when messaging is stopped
   */
  event MessagingStopped();

  /**
   * @notice Emitted when a message is sent to the linked adapter
   * @param _user The user that sent the message
   * @param _to The target address on the destination chain
   * @param _amount The amount of tokens to send
   * @param _minGasLimit Minimum gas limit that the message can be executed with
   */
  event MessageSent(address _user, address _to, uint256 _amount, uint32 _minGasLimit);

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
  error IOpUSDCBridgeAdapter_InvalidSender();

  /**
   * @notice Error when the nonce is invalid
   */
  error IOpUSDCBridgeAdapter_InvalidNonce();

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Send the message to the linked adapter to mint the bridged representation on the linked chain
   * @param _to The target address on the destination chain
   * @param _amount The amount of tokens to send
   * @param _minGasLimit Minimum gas limit that the message can be executed with
   */
  function sendMessage(address _to, uint256 _amount, uint32 _minGasLimit) external;

  /**
   * @notice Send the message to the linked adapter to mint the bridged representation on the linked chain
   * @param _to The target address on the destination chain
   * @param _amount The amount of tokens to send
   * @param _nonce The nonce of the user
   * @param _signature The signature of the user
   * @param _minGasLimit Minimum gas limit that the message can be executed with
   */
  function sendMessage(
    address _to,
    uint256 _amount,
    uint256 _nonce,
    bytes calldata _signature,
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
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Fetches address of the USDC token
   * @return _usdc Address of the USDC token
   */
  // solhint-disable-next-line func-name-mixedcase
  function USDC() external view returns (address _usdc);

  /**
   * @notice Fetches address of the CrossDomainMessenger to send messages to L1 <-> L2
   * @return _messenger Address of the messenger
   */
  // solhint-disable-next-line func-name-mixedcase
  function MESSENGER() external view returns (address _messenger);

  /**
   * @notice Fetches address of the linked adapter on L2 to send messages to and receive from
   * @return _linkedAdapter Address of the linked adapter
   */
  // solhint-disable-next-line func-name-mixedcase
  function LINKED_ADAPTER() external view returns (address _linkedAdapter);

  /**
   * @notice Fetches whether messaging is disabled
   * @return _isMessagingDisabled Whether messaging is disabled
   */
  function isMessagingDisabled() external view returns (bool _isMessagingDisabled);

  /**
   * @notice Returns the nonce of a given user to avoid replay attacks
   * @param _user The user to fetch the nonce for
   * @return _nonce The nonce of the user
   */
  function userNonce(address _user) external view returns (uint256 _nonce);
}
