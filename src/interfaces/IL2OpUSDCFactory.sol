// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IL2OpUSDCFactory {
  /*///////////////////////////////////////////////////////////////
                            ERRORS
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice Thrown when the deployment failed
   */
  error IL2OpUSDCFactory_CreateDeploymentFailed();

  /**
   * @notice Thrown when an USDC initialization tx failed
   */
  error IL2OpUSDCFactory_UsdcInitializationFailed();

  /**
   * @notice Thrown when an adapter initialization tx failed
   */
  error IL2OpUSDCFactory_AdapterInitializationFailed();

  /*///////////////////////////////////////////////////////////////
                            EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when the USDC implementation is deployed
   * @param _usdcImplementation The address of the USDC implementation
   */
  event DeployedUSDCImpl(address _usdcImplementation);

  /**
   * @notice Emitted when the USDC proxy is deployed
   * @param _usdcProxy The address of the USDC proxy
   */
  event DeployedUSDCProxy(address _usdcProxy);

  /**
   * @notice Emitted when the `L2OpUSDCBridgeAdapter` is deployed
   * @param _l2Adapter The address of the L2 adapter
   */
  event DeployedL2Adapter(address _l2Adapter);
}
