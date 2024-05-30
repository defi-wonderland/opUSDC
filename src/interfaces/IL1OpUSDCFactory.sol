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
   * @param _l1Messenger The address of the L1 messenger for the L2 Op chain
   * @param _minGasLimitFactory The minimum gas limit for the L2 factory deployment
   * @param _minGasLimitDeploy The minimum gas limit for calling the `deploy` function on the L2 factory
   * @dev We deploy the proxies with the 0 address as implementation and then upgrade them with the actual
   * implementation because the `CREATE2` opcode is dependent on the creation code and a different implementation
   */
  function deployL2UsdcAndAdapter(address _l1Messenger, uint32 _minGasLimitFactory, uint32 _minGasLimitDeploy) external;
  /*///////////////////////////////////////////////////////////////
                            VARIABLES
  //////////////////////////////////////////////////////////////*/

  /**
   * @return _l2Messenger The address of the L2 messenger
   */
  // solhint-disable-next-line func-name-mixedcase
  function L2_MESSENGER() external view returns (address _l2Messenger);

  /**
   * @return _l2Factory The address of the L1 factory
   */
  // solhint-disable-next-line func-name-mixedcase
  function L2_FACTORY() external view returns (address _l2Factory);

  /**
   * @return _upgradeManager The address of the UpgradeManager contract
   */
  // solhint-disable-next-line func-name-mixedcase
  function UPGRADE_MANAGER() external view returns (IUpgradeManager _upgradeManager);

  /**
   * @return _l1AdapterProxy The address of the L1OpUSDCBridgeAdapter contract
   */
  // solhint-disable-next-line func-name-mixedcase
  function L1_ADAPTER_PROXY() external view returns (L1OpUSDCBridgeAdapter _l1AdapterProxy);

  /**
   * @return _l2AdapterProxy The address of the L2OpUSDCBridgeAdapter proxy contract
   */
  // solhint-disable-next-line func-name-mixedcase
  function L2_ADAPTER_PROXY() external view returns (address _l2AdapterProxy);

  /**
   * @return _l2UsdcProxy The address of the USDC proxy contract on L2
   */
  // solhint-disable-next-line func-name-mixedcase
  function L2_USDC_PROXY() external view returns (address _l2UsdcProxy);

  /**
   * @notice Checks if a messenger has a protocol deployed for it
   * @param _messenger The address of the L1 messenger
   * @return _deployed Whether the messenger has a protocol deployed for it
   */
  function isMessengerDeployed(address _messenger) external view returns (bool _deployed);
}
