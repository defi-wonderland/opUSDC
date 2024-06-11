// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// solhint-disable func-name-mixedcase

interface IL2OpUSDCFactory {
  /*///////////////////////////////////////////////////////////////
                            EVENTS
  ///////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when the contracts are deployed
   * @param _l1Adapter The address of the L1 adapter
   * @param _usdcProxy The address of the USDC proxy
   * @param _usdcImplementation The address of the USDC implementation
   */
  event L2ContractsDeployed(address _l1Adapter, address _usdcProxy, address _usdcImplementation);

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
   * @notice Thrown when the `CREATE2` deployment failed
   */
  error IL2OpUSDCFactory_Create2DeploymentFailed();

  /**
   * @notice Thrown when the `CREATE` deployment failed
   */
  error IL2OpUSDCFactory_CreateDeploymentFailed();

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
