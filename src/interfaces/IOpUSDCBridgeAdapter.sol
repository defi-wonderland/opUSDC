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

  event MessageRecieved(address _user, uint256 _amount);

  /*///////////////////////////////////////////////////////////////
                            ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Error when the caller is not the token issuer
   */
  error IOpUSDCBridgeAdapter_NotTokenIssuer();

  /**
   * @notice Error when the caller is not the linked adapter
   */
  error IOpUSDCBridgeAdapter_NotLinkedAdapter();

  /**
   * @notice Error when the function is only callable on L1
   */

  error IOpUSDCBridgeAdapter_OnlyOnL1();

  /**
   * @notice Error when a message is trying to be sent when linked adapter is not set
   */

  error IOpUSDCBridgeAdapter_LinkedAdapterNotSet();

  /*///////////////////////////////////////////////////////////////
                            VARIABLES
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Fetches address of the Bridged USDC token
   * @return _bridgedUSDC Address of the bridged USDC token
   */
  function BRIDGED_USDC() external view returns (address _bridgedUSDC);

  /**
   * @notice Fetches address of the L1  canonical USDC token
   * @return _l1USDC Address of the L1 USDC token
   */
  function L1_USDC() external view returns (address _l1USDC);

  /**
   * @notice Fetches address of the OpUSDC Lockbox
   * @dev Should be address(0) on L2's
   * @return _lockbox Address of the lockbox
   */
  function LOCKBOX() external view returns (address _lockbox);

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

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  //////////////////////////////////////////////////////////////*/
}
