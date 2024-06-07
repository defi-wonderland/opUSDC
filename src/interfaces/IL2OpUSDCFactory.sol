// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// solhint-disable func-name-mixedcase

interface IL2OpUSDCFactory {
  /*///////////////////////////////////////////////////////////////
                            EVENTS
  ///////////////////////////////////////////////////////////////*/

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

  /*///////////////////////////////////////////////////////////////
                            ERRORS
  ///////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when the USDC admin is invalid
   */
  error IL2OpUSDCFactory_InvalidUSDCAdmin();

  /**
   * @notice Thrown when the caller is not the L2 messenger, or the cross domain caller is not the L1 factory
   */
  error IL2OpUSDCFactory_InvalidSender();

  /**
   * @notice Thrown when the deployment failed
   */
  error IL2OpUSDCFactory_Create2DeploymentFailed();

  /**
   * @notice Thrown when an USDC initialization tx failed
   */
  error IL2OpUSDCFactory_InitializationFailed();

  /*///////////////////////////////////////////////////////////////
                            VARIABLES
  ///////////////////////////////////////////////////////////////*/

  /**
   * @return _l2Messenger The address of the L2 messenger
   */
  function L2_MESSENGER() external view returns (address _l2Messenger);

  /**
   * @return _l1Factory The address of the L1 factory
   */
  function L1_FACTORY() external view returns (address _l1Factory);
}
