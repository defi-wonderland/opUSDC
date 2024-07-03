// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IL2OpUSDCFactory {
  /*///////////////////////////////////////////////////////////////
                            STRUCTS
  ///////////////////////////////////////////////////////////////*/

  /**
   * @notice The struct to hold the USDC data for the name, symbol, currency, and decimals when initializing
   * @param _tokenName The name of the USDC token
   * @param _tokenSymbol The symbol of the USDC token
   * @param _tokenCurrency The currency that the USDC token represents
   * @param _tokenDecimals The number of decimals that the USDC token uses
   */
  struct USDCInitializeData {
    string _tokenName;
    string _tokenSymbol;
    string _tokenCurrency;
    uint8 _tokenDecimals;
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
   * @return _l1Adapter The address of the L1 adapter
   * @dev There are no permissioned checks to allow the message replayability in case it fails. But it doesn't harm
   * since even though other L2 contracts can be deployed, the L1 counterpart is not deployed nor setup
   */
  function L1_ADAPTER() external view returns (address _l1Adapter);
}
