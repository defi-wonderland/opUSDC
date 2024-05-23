// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IOpUSDCBridgeAdapter {
  /*///////////////////////////////////////////////////////////////
                            EVENTS
  //////////////////////////////////////////////////////////////*/

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

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  //////////////////////////////////////////////////////////////*/

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
   * @notice Fetches address of the linked adapter on L2 to send messages to and receive from
   * @return _linkedAdapter Address of the linked adapter
   */
  // solhint-disable-next-line func-name-mixedcase
  function LINKED_ADAPTER() external view returns (address _linkedAdapter);
}
