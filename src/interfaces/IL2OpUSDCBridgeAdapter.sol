// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IL2OpUSDCBridgeAdapter {
  /*///////////////////////////////////////////////////////////////
                            EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when the new USDC implementation is deployed
   * @param _l2UsdcImplementation The address of the L2 USDC implementation
   */
  event DeployedL2UsdcImplementation(address _l2UsdcImplementation);

  /*///////////////////////////////////////////////////////////////
                            ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Error when the adapter initialization fails
   */
  error L2OpUSDCBridgeAdapter_AdapterInitializationFailed();

  /**
   * @notice Error when the USDC initialization fails
   */
  error L2OpUSDCBridgeAdapter_UsdcInitializationFailed();

  /**
   * @notice Error when the flow is disabled
   */
  error L2OpUSDCBridgeAdapter_DisabledFlow();

  /**
   * @notice Error when the initialization has already been executed
   */
  error L2OpUSDCBridgeAdapter_InitializationAlreadyExecuted();

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice Receive the stop messaging message from the linked adapter and stop outgoing messages
   */
  function receiveStopMessaging() external;

  /**
   * @notice Send the message to the linked adapter to mint the bridged representation on the linked chain
   * @param _to The target address on the destination chain
   * @param _amount The amount of tokens to send
   * @param _minGasLimit Minimum gas limit that the message can be executed with
   */
  function sendMessage(address _to, uint256 _amount, uint32 _minGasLimit) external;

  /**
   * @notice Resume messaging after it was stopped
   */
  function receiveResumeMessaging() external;

  /**
   * @notice Receive the creation code from the linked adapter, deploy the new implementation and upgrade
   * @param _l2AdapterBytecode The bytecode for the new L2 adapter implementation
   * @param _l2AdapterInitTxs The initialization transactions for the new L2 adapter implementation
   */
  function receiveAdapterUpgrade(bytes calldata _l2AdapterBytecode, bytes[] calldata _l2AdapterInitTxs) external;

  /**
   * @notice Receive the creation code from the linked adapter, deploy the new implementation and upgrade
   * @param _l2UsdcBytecode The bytecode for the new L2 USDC implementation
   * @param _l2UsdcInitTxs The initialization transactions for the new L2 USDC implementation
   */
  function receiveUsdcUpgrade(bytes calldata _l2UsdcBytecode, bytes[] memory _l2UsdcInitTxs) external;

  /**
   * @notice Send the message to the linked adapter to mint the bridged representation on the linked chain
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
   * @notice Set _lastL2UsdcInitTxsLength to the new value
   * @param _newLength The new value for _lastL2UsdcInitTxsLength
   */
  function setLastUsdcInitTxsLength(uint256 _newLength) external;

  /*///////////////////////////////////////////////////////////////
                            VARIABLES
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice Fetches address of the CrossDomainMessenger to send messages to L1 <-> L2
   * @return _messenger Address of the messenger
   */
  // solhint-disable-next-line func-name-mixedcase
  function MESSENGER() external view returns (address _messenger);

  /**
   * @notice Fetches whether messaging is disabled
   * @return _isMessagingDisabled Whether messaging is disabled
   */
  function isMessagingDisabled() external view returns (bool _isMessagingDisabled);
}
