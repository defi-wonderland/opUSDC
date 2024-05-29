// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IUpgradeManager} from 'interfaces/IUpgradeManager.sol';

interface IL1OpUSDCFactory {
  /*///////////////////////////////////////////////////////////////
                            EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when the `L1OpUSDCBridgeAdapter` is deployed
   * @param _l1Adapter The address of the L1 adapter
   */
  event L1AdapterDeployed(address _l1Adapter);

  /**
   * @notice Emitted when the `UpgradeManager` is deployed
   * @param _upgradeManager The address of the upgrade manager
   */
  event UpgradeManagerDeployed(address _upgradeManager);

  /*///////////////////////////////////////////////////////////////
                            ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Error when the messenger already has a protocol deployed for it
   */
  error IL1OpUSDCFactory_MessengerAlreadyDeployed();

  /**
   * @notice Error when the caller is not the executor
   */
  error IL1OpUSDCFactory_NotExecutor();

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Sends the L2 factory creation tx along with the L2 deployments to be done on it through the portal
   * @param _portal The address of the portal contract for the respective L2 chain
   * @param _minGasLimit The minimum gas limit for the L2 deployment
   */
  function deployL2UsdcAndAdapter(address _portal, uint32 _minGasLimit) external;

  /*///////////////////////////////////////////////////////////////
                            VARIABLES
  //////////////////////////////////////////////////////////////*/
  /**
   * @return _l2Messenger The address of the L2 messenger
   */
  function L2_MESSENGER() external view returns (address _l2Messenger);

  /**
   * @return _upgradeManager The address of the UpgradeManager contract
   */
  function UPGRADE_MANAGER() external view returns (IUpgradeManager _upgradeManager);

  /**
   * @return _l1Adapter The address of the L1OpUSDCBridgeAdapter contract
   */
  function L1_ADAPTER() external view returns (address _l1Adapter);

  /**
   * @return _l2AdapterImplementation The address of the L2OpUSDCBridgeAdapter implementation contract
   */
  function L2_ADAPTER_IMPLEMENTATION() external view returns (address _l2AdapterImplementation);

  /**
   * @return _l2AdapterProxy The address of the L2OpUSDCBridgeAdapter proxy contract
   */
  function L2_ADAPTER_PROXY() external view returns (address _l2AdapterProxy);

  /**
   * @return _l2UsdcProxy The address of the USDC proxy contract on L2
   */
  function L2_USDC_PROXY() external view returns (address _l2UsdcProxy);

  /**
   * @return _l2UsdcImplementation The address of the USDC implementation contract on L2
   * @dev This is the first USDC implementation address deployed by the L2 factory. However, if then it gets updated,
   * the implementation address will be another one.
   */
  function L2_USDC_IMPLEMENTATION() external view returns (address _l2UsdcImplementation);

  /**
   * @return _aliasedSelf The aliased address of the L1 factory contract on L2
   * @dev This is the `msg.sender` that will deploy the L2 factory
   */
  function ALIASED_SELF() external view returns (address _aliasedSelf);

  /**
   * @notice Checks if a messenger has a protocol deployed for it
   * @param _messenger The address of the L1 messenger
   * @return _deployed Whether the messenger has a protocol deployed for it
   */
  function isMessengerDeployed(address _messenger) external view returns (bool _deployed);
}
