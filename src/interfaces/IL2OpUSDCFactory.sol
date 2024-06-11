// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// solhint-disable func-name-mixedcase

interface IL2OpUSDCFactory {
  /*///////////////////////////////////////////////////////////////
                            EVENTS
  ///////////////////////////////////////////////////////////////*/

  event Create2DeploymentFailed();

  event CreateDeploymentFailed();

  event USDCImplementationDeployed();
  event USDCProxyDeployed();
  event L2AdapterDeployed();

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

  error IL2OpUSDCFactory_DeploymentsFailed();

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
