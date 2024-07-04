// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IL2OpUSDCFactory {
  /*///////////////////////////////////////////////////////////////
                            STRUCTS
  ///////////////////////////////////////////////////////////////*/

  /**
   * @notice The struct to hold the USDC data for the name, symbol, currency, and decimals when initializing
   * @param tokenName The name of the USDC token
   * @param tokenSymbol The symbol of the USDC token
   * @param tokenCurrency The currency that the USDC token represents
   * @param tokenDecimals The number of decimals that the USDC token uses
   */
  struct USDCInitializeData {
    string tokenName;
    string tokenSymbol;
    string tokenCurrency;
    uint8 tokenDecimals;
  }

  /*///////////////////////////////////////////////////////////////
                            EVENTS
  ///////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when the USDC implementation is deployed
   * @param _l2UsdcImplementation The address of the L2 USDC implementation
   */
  event USDCImplementationDeployed(address _l2UsdcImplementation);

  /**
   * @notice Emitted when the USDC proxy is deployed
   * @param _l2UsdcProxy The address of the L2 USDC proxy
   */
  event USDCProxyDeployed(address _l2UsdcProxy);

  /**
   * @notice Emitted when the L2 adapter is deployed
   * @param _l2Adapter The address of the L2 adapter
   */
  event L2AdapterDeployed(address _l2Adapter);

  /*///////////////////////////////////////////////////////////////
                            ERRORS
  ///////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when the caller is not the L1 messenger or the x doman caller is not the L1 factory
   */
  error IL2OpUSDCFactory_InvalidSender();

  /**
   * @notice Thrown when a contract deployment fails
   */
  error IL2OpUSDCFactory_DeploymentFailed();

  /**
   * @notice Thrown when an USDC initialization tx failed
   * @param _txIndex The index of the failed initialization tx
   */
  error IL2OpUSDCFactory_InitializationFailed(uint256 _txIndex);

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  ///////////////////////////////////////////////////////////////*/

  /**
   * @notice Deploys the USDC implementation, proxy, and L2 adapter contracts all at once, and then initializes the USDC
   * @param _l2AdapterOwner The address of the L2 adapter owner
   * @param _usdcImplementationInitCode The creation code with the constructor arguments for the USDC implementation
   * @param _usdcInitializeData The USDC name, symbol, currency, and decimals used on the first `initialize()` call
   * @param _usdcInitTxs The initialization transactions for the USDC proxy and implementation contracts
   * @dev The USDC proxy owner needs to be set on the first init tx, and will be set to the L2 adapter address
   * @dev Using `CREATE` to guarantee that the addresses are unique among all the L2s
   * @dev This function can be called after the first deployments are set, but is useless since the L1 setup and
   * deployments are not settled
   */
  function deploy(
    address _l2AdapterOwner,
    bytes memory _usdcImplementationInitCode,
    USDCInitializeData memory _usdcInitializeData,
    bytes[] memory _usdcInitTxs
  ) external;

  /*///////////////////////////////////////////////////////////////
                            VARIABLES
  ///////////////////////////////////////////////////////////////*/

  /**
   * @return _l2Messenger The address of the L2 messenger
   */
  // solhint-disable-next-line func-name-mixedcase
  function L2_MESSENGER() external view returns (address _l2Messenger);

  /**
   * @return _l1Factory The address of the L1 factory
   */
  // solhint-disable-next-line func-name-mixedcase
  function L1_FACTORY() external view returns (address _l1Factory);

  /**
   * @return _l1Adapter The address of the L1 adapter
   * @dev There are no permissioned checks to allow the message replayability in case it fails. But it doesn't harm
   * since even though other L2 contracts can be deployed, the L1 counterpart is not deployed nor setup
   */
  // solhint-disable-next-line func-name-mixedcase
  function L1_ADAPTER() external view returns (address _l1Adapter);
}
