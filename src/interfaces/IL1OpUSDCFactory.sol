// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {L1OpUSDCBridgeAdapter} from 'contracts/L1OpUSDCBridgeAdapter.sol';
import {IUpgradeManager} from 'interfaces/IUpgradeManager.sol';

// solhint-disable func-name-mixedcase

interface IL1OpUSDCFactory {
  /*///////////////////////////////////////////////////////////////
                            EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when the `L1OpUSDCBridgeAdapter` is deployed
   * @param _l1AdapterProxy The address of the L1 adapter proxy
   * @param _l1AdapterImplementation The address of the L1 adapter implementation
   */
  event L1AdapterDeployed(address _l1AdapterProxy, address _l1AdapterImplementation);

  /**
   * @notice Emitted when the `UpgradeManager` is deployed
   * @param _upgradeManagerProxy The address of the upgrade manager proxy
   * @param _upgradeManagerImplementation The address of the upgrade manager implementation
   */
  event UpgradeManagerDeployed(address _upgradeManagerProxy, address _upgradeManagerImplementation);

  /*///////////////////////////////////////////////////////////////
                            ERRORS
  //////////////////////////////////////////////////////////////*/

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
   * @notice Thrown when the USDC admin is equal to the L2 factory address
   */
  error IL1OpUSDCFactory_InvalidUSDCAdmin();

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Sends the L2 factory creation tx along with the L2 deployments to be done on it through the messenger
   * @param _l1Messenger The address of the L1 messenger for the L2 Op chain
   * @param _usdcAdmin The address of the USDC admin
   * @param _minGasLimitCreate2Factory The minimum gas limit for the L2 factory deployment
   * @param _minGasLimitDeploy The minimum gas limit for calling the `deploy` function on the L2 factory
   */
  function deployL2FactoryAndContracts(
    address _l1Messenger,
    address _usdcAdmin,
    uint32 _minGasLimitCreate2Factory,
    uint32 _minGasLimitDeploy
  ) external;

  /**
   * @notice Sends the L2 USDC and adapter deployments tx through the messenger to be executed on the l2 factory
   * @param _l1Messenger The address of the L1 messenger for the L2 Op chain
   * @param _usdcAdmin The address of the USDC admin
   * @param _minGasLimitDeploy The minimum gas limit for calling the `deploy` function on the L2 factory
   */
  function deployL2USDCAndAdapter(address _l1Messenger, address _usdcAdmin, uint32 _minGasLimitDeploy) external;

  /*///////////////////////////////////////////////////////////////
                            VARIABLES
  //////////////////////////////////////////////////////////////*/

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
   * @return _upgradeManager The address of the UpgradeManager contract
   */
  function UPGRADE_MANAGER() external view returns (IUpgradeManager _upgradeManager);

  /**
   * @return _l1AdapterProxy The address of the L1OpUSDCBridgeAdapter contract
   */
  function L1_ADAPTER_PROXY() external view returns (L1OpUSDCBridgeAdapter _l1AdapterProxy);

  /**
   * @return _l2AdapterProxy The address of the L2OpUSDCBridgeAdapter proxy contract
   */
  function L2_ADAPTER_PROXY() external view returns (address _l2AdapterProxy);

  /**
   * @return _l2UsdcProxy The address of the USDC proxy contract on L2
   */
  function L2_USDC_PROXY() external view returns (address _l2UsdcProxy);

  /**
   * @notice Checks if the `L2OpUSDCFactory` has been deployed on L2 by the given messenger
   * @param _l1Messenger The address of the L1 messenger
   * @return _deployed Whether the messenger has a factory deployed for it on L2
   */
  function isFactoryDeployed(address _l1Messenger) external view returns (bool _deployed);
}
