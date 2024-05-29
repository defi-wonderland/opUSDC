// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IL2OpUSDCFactory {
  /*///////////////////////////////////////////////////////////////
                            ERRORS
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice Thrown when the deployment failed
   */
  error IL2OpUSDCFactory_Create2DeploymentFailed();

  /**
   * @notice Thrown when an USDC initialization tx failed
   */
  error IL2OpUSDCFactory_InitializationFailed();

  /*///////////////////////////////////////////////////////////////
                            EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * /**
   * @notice Emitted when the USDC proxy is deployed
   * @param _usdcProxy The address of the USDC proxy
   * @param _usdcImplementation The address of the USDC implementation
   */
  event USDCDeployed(address _usdcProxy, address _usdcImplementation);

  /**
   * @notice Emitted when the L2 adapter proxy is deployed
   * @param _adapterProxy The address of the L2 adapter proxy
   * @param _adapterImplementation The address of the L2 adapter implementation
   */
  event AdapterDeployed(address _adapterProxy, address _adapterImplementation);
}
