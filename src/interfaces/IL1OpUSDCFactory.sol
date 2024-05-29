// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {L1OpUSDCBridgeAdapter} from 'contracts/L1OpUSDCBridgeAdapter.sol';
import {IUpgradeManager} from 'interfaces/IUpgradeManager.sol';

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
                            LOGIC
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
   * @return _l1AdapterProxy The address of the L1OpUSDCBridgeAdapter proxy  contract
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
   * @return _aliasedSelf The aliased address of the L1 factory contract on L2
   * @dev This is the `msg.sender` that will deploy the L2 factory
   */
  function ALIASED_SELF() external view returns (address _aliasedSelf);

  /**
   * @notice Sends the L2 factory creation tx along with the L2 deployments to be done on it through the portal
   * @param _portal The address of the portal contract for the respective L2 chain
   * @param _minGasLimit The minimum gas limit for the L2 deployment
   */
  function deployL2UsdcAndAdapter(address _portal, uint32 _minGasLimit) external;
}
