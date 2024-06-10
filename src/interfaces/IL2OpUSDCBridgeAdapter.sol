// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IL2OpUSDCBridgeAdapter {
  /*///////////////////////////////////////////////////////////////
                            EVENTS
  ///////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when the new USDC implementation is deployed
   * @param _l2UsdcImplementation The address of the L2 USDC implementation
   */
  event DeployedL2UsdcImplementation(address _l2UsdcImplementation);

  /*///////////////////////////////////////////////////////////////
                            ERRORS
  ///////////////////////////////////////////////////////////////*/

  /**
   * @notice Error when the USDC initialization fails
   */
  error L2OpUSDCBridgeAdapter_UsdcInitializationFailed();

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
   * @notice Receive the creation code from the linked adapter, deploy the new implementation and upgrade
   * @param _l2UsdcBytecode The bytecode for the new L2 USDC implementation
   * @param _l2UsdcImplTxs The initialization transactions for the new L2 USDC implementation
   * @param _l2UsdcProxyTxs The initialization transactions for the proxy contract
   */
  function receiveUsdcUpgrade(
    bytes calldata _l2UsdcBytecode,
    bytes[] memory _l2UsdcImplTxs,
    bytes[] memory _l2UsdcProxyTxs
  ) external;

  /*///////////////////////////////////////////////////////////////
                            VARIABLES
  ///////////////////////////////////////////////////////////////*/
  /**
   * @notice Fetches whether messaging is disabled
   * @return _isMessagingDisabled Whether messaging is disabled
   */
  function isMessagingDisabled() external view returns (bool _isMessagingDisabled);
}
