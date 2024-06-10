// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {L1OpUSDCBridgeAdapter} from 'contracts/L1OpUSDCBridgeAdapter.sol';

// solhint-disable func-name-mixedcase

interface IL1OpUSDCFactory {
  /*///////////////////////////////////////////////////////////////
                            EVENTS
  ///////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when the `L1OpUSDCBridgeAdapter` is deployed
   * @param _l1Adapter The address of the L1 adapter
   */
  event L1AdapterDeployed(address _l1Adapter);

  /**
   * @notice Emitted when the `UpgradeManager` is deployed
   * @param _upgradeManagerProxy The address of the upgrade manager proxy
   * @param _upgradeManagerImplementation The address of the upgrade manager implementation
   */
  event UpgradeManagerDeployed(address _upgradeManagerProxy, address _upgradeManagerImplementation);

  /*///////////////////////////////////////////////////////////////
                            ERRORS
  ///////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when the caller is not the executor
   */
  error IL1OpUSDCFactory_NotExecutor();

  /**
   * @notice Thrown when the factory on L2 for the given messenger is not deployed and the `deployL2USDCAndAdapter` is
   * called
   */
  error IL1OpUSDCFactory_FactoryNotDeployed();

  /**
   * @notice Thrown if the nonce is greater than 2**64-2 while precalculating the L1 Adapter using `CREATE`
   */
  error IL1OpUSDCFactory_InvalidNonce();

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  ///////////////////////////////////////////////////////////////*/

  /**
   * @notice Sends the L2 factory creation tx along with the L2 deployments to be done on it through the messenger
   * @param _l1Messenger The address of the L1 messenger for the L2 Op chain
   * @param _l1AdapterOwner The address of the owner of the L1 adapter
   * @param _minGasLimitCreate2Factory The minimum gas limit for the L2 factory deployment
   * @param _minGasLimitDeploy The minimum gas limit for calling the `deploy` function on the L2 factory
   * @param _usdcInitTxs The initialization transactions to be executed on the USDC contract
   */
  function deployL2FactoryAndContracts(
    address _l1Messenger,
    address _l1AdapterOwner,
    uint32 _minGasLimitCreate2Factory,
    uint32 _minGasLimitDeploy,
    bytes[] memory _usdcInitTxs
  ) external;

  /**
   * @notice Sends the L2 adapter and USDC proxy and implementation deployments tx through the messenger
   * to be executed on the l2 factory
   * @param _l1Messenger The address of the L1 messenger for the L2 Op chain
   * @param _l1AdapterOwner The address of the owner of the L1 adapter
   * @param _usdcInitTxs The initialization transactions to be executed on the USDC contract
   * @param _minGasLimitDeploy The minimum gas limit for calling the `deploy` function on the L2 factory
   */
  function deployAdapters(
    address _l1Messenger,
    address _l1AdapterOwner,
    bytes[] memory _usdcInitTxs,
    uint32 _minGasLimitDeploy
  ) external;

  /*///////////////////////////////////////////////////////////////
                            VARIABLES
  ///////////////////////////////////////////////////////////////*/

  /**
   * @return _usdc The address of USDC on L1
   */
  function USDC() external view returns (address _usdc);

  /**
   * @return _l2Messenger The address of the L2 messenger
   */
  function L2_MESSENGER() external view returns (address _l2Messenger);

  /**
   * @return _l2Create2Deployer The address of the `create2Deployer` contract on L2
   */
  function L2_CREATE2_DEPLOYER() external view returns (address _l2Create2Deployer);

  /**
   * @return _l2Factory The address of the L1 factory
   */
  function L2_FACTORY() external view returns (address _l2Factory);

  /**
   * @return _nonce The nonce counter of the factory contract
   */
  function nonce() external view returns (uint256 _nonce);

  /**
   * @notice Checks if the `L2OpUSDCFactory` has been deployed on L2 by the given messenger
   * @param _l1Messenger The address of the L1 messenger
   * @return _deployed Whether the messenger has a factory deployed for it on L2
   * @dev It is initialized to `1` to avoid updating from zero to a non-zero value which is more expensive
   */
  function isFactoryDeployed(address _l1Messenger) external view returns (bool _deployed);
}
