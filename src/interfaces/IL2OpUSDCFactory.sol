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
}
