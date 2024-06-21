// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IL2OpUSDCBridgeAdapter {
  /*///////////////////////////////////////////////////////////////
                            EVENTS
  ///////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when the owner message is sent
   */
  event UsdcFunctionSent(bytes4 _functionSignature);

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  ///////////////////////////////////////////////////////////////*/
  /**
   * @notice Initiates the process to migrate the bridged USDC to native USDC
   * @dev Full migration cant finish until L1 receives the message for setting the burn amount
   * @param _newOwner The address to transfer ownerships to
   * @param _setBurnAmountMinGasLimit Minimum gas limit that the setBurnAmount message can be executed on L1
   */
  function receiveMigrateToNative(address _newOwner, uint32 _setBurnAmountMinGasLimit) external;

  /**
   * @notice Receive the stop messaging message from the linked adapter and stop outgoing messages
   */
  function receiveStopMessaging() external;

  /**
   * @notice Resume messaging after it was stopped
   */
  function receiveResumeMessaging() external;

  /**
   * @notice Call with abitrary calldata on USDC contract.
   * @dev can't execute the following list of transactions:
   *  • transferOwnership (0xf2fde38b)
   *  • changeAdmin (0x8f283970)
   * @param _data The calldata to execute on the USDC contract
   */
  function callUsdcTransaction(bytes calldata _data) external;

  /*///////////////////////////////////////////////////////////////
                            VARIABLES
  ///////////////////////////////////////////////////////////////*/
  /**
   * @notice Fetches whether messaging is disabled
   * @return _isMessagingDisabled Whether messaging is disabled
   */
  function isMessagingDisabled() external view returns (bool _isMessagingDisabled);
}
