// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IL1OpUSDCBridgeAdapter} from 'interfaces/IL1OpUSDCBridgeAdapter.sol';
import {IUpgradeManager} from 'interfaces/IUpgradeManager.sol';
import {ICrossDomainMessenger} from 'interfaces/external/ICrossDomainMessenger.sol';
import {IOptimismPortal} from 'interfaces/external/IOptimismPortal.sol';

interface IL1OpUSDCFactory {
  event L1AdapterDeployed(address _l1Adapter);

  event UpgradeManagerDeployed(address _upgradeManager);

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
  function L1_ADAPTER() external view returns (IL1OpUSDCBridgeAdapter _l1Adapter);

  /**
   * @return _l2Factory The address of the L2OpUSDCFactory contract
   */
  function L2_FACTORY() external view returns (address _l2Factory);

  /**
   * @return _l2Adapter The address of the L2OpUSDCBridgeAdapter contract
   */
  function L2_ADAPTER() external view returns (address _l2Adapter);

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

  function deployL2UsdcAndAdapter(address _l1Messenger, uint32 _minGasLimit) external;
}
