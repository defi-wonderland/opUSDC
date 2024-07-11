// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {FallbackProxyAdmin} from 'contracts/utils/FallbackProxyAdmin.sol';

interface IL2OpUSDCBridgeAdapter {
  /*///////////////////////////////////////////////////////////////
                            EVENTS
  ///////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when the owner message is sent
   * @param _functionSignature The signature of the function sent
   */
  event UsdcFunctionSent(bytes4 _functionSignature);

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  ///////////////////////////////////////////////////////////////*/
  /**
   * @notice Initiates the process to migrate the bridged USDC to native USDC
   * @dev Full migration cant finish until L1 receives the message for setting the burn amount
   * @param _roleCaller The address that will be allowed to transfer the USDC roles
   * @param _setBurnAmountMinGasLimit Minimum gas limit that the setBurnAmount message can be executed on L1
   */
  function receiveMigrateToNative(address _roleCaller, uint32 _setBurnAmountMinGasLimit) external;

  /**
   * @notice Transfer the USDC roles to the new owner
   * @param _owner The address to transfer ownerships to
   * @dev n only be called by the role caller set in the migration process
   */
  function transferUSDCRoles(address _owner) external;

  /**
   * @notice Receive the stop messaging message from the linked adapter and stop outgoing messages
   */
  function receiveStopMessaging() external;

  /**
   * @notice Resume messaging after it was stopped
   */
  function receiveResumeMessaging() external;

  /**
   * @notice Call with abitrary calldata on USDC contract.
   * @dev can't execute the following list of transactions:
   *  • transferOwnership (0xf2fde38b)
   *  • changeAdmin (0x8f283970)
   * @dev UpgradeTo and UpgradeToAndCall go through the fallback admin
   * @param _data The calldata to execute on the USDC contract
   */
  function callUsdcTransaction(bytes calldata _data) external;

  /*///////////////////////////////////////////////////////////////
                            VARIABLES
  ///////////////////////////////////////////////////////////////*/
  /**
   * @notice Fetches whether messaging is disabled
   * @return _isMessagingDisabled Whether messaging is disabled
   */
  function isMessagingDisabled() external view returns (bool _isMessagingDisabled);

  /**
   * @notice Fetches the address of the role caller
   * @return _roleCaller The address of the role caller
   */
  function roleCaller() external view returns (address _roleCaller);

  /**
   * @return _fallbackProxyAdmin The address of the fallback proxy admin
   * @dev The admin can't call the fallback function of the USDC proxy, meaning it can't interact with the functions
   * such as mint and burn between others. Because of this, the FallbackProxyAdmin contract is used as a middleware,
   * being controlled by the L2OpUSDCBridgeAdapter contract and allowing to call the admin functions through it while
   * also being able to call the fallback function of the USDC proxy.
   */
  // solhint-disable-next-line func-name-mixedcase
  function FALLBACK_PROXY_ADMIN() external view returns (FallbackProxyAdmin _fallbackProxyAdmin);
}
