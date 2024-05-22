// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ICreateX} from 'interfaces/external/ICreateX.sol';
import {ICrossDomainMessenger} from 'interfaces/external/ICrossDomainMessenger.sol';
import {IOptimismPortal} from 'interfaces/external/IOptimismPortal.sol';

interface IL1OpUSDCFactory {
  /**
   * @notice Deploy params needed to call the `deploy()` function
   * @param usdc The address of the USDC contract on L1
   * @param portal The address of the Optimism portal contract on L1
   * @param l1Messenger The address of the L1 CrossDomainMessenger
   * @param l2Messenger The address of the L2 CrossDomainMessenger
   * @param l1dapterCreationCode The creation code of the `L1OpUSDCBridgeAdapter` contract
   * @param l2AdapterCreationCode The creation code of the `L2OpUSDCBridgeAdapter` contract
   * @param usdcProxyCreationCode The creation code of the USDC proxy contract
   * @param usdcImplementationCreationCode The creation code of the USDC implementation contract
   * @param owner The owner of the `L1OpUSDCBridgeAdapter` contract
   * @param minGasLimit The minimum gas limit to deploy the `L2OpUSDCFactory` on L2.
   * @param l2ChainId The chain ID of the L2 network
   */
  struct DeployParams {
    address usdc;
    IOptimismPortal portal;
    ICrossDomainMessenger l1Messenger;
    address l2Messenger;
    bytes l1AdapterCreationCode;
    bytes l2AdapterCreationCode;
    bytes usdcImplementationCreationCode;
    bytes usdcProxyCreationCode;
    address owner;
    uint32 minGasLimit;
  }

  /**
   * @notice Deployment addresses of the contracts deployed by the `deploy()` function
   * @param l2Factory The address of the L2OpUSDCFactory contract
   * @param l1Adapter The address of the L1OpUSDCAdapter contract
   * @param l2Adapter The address of the L2OpUSDCAdapter contract
   * @param l2UsdcImplementation The address of the USDC implementation contract on L2
   * @param l2UsdcProxy The address of the USDC proxy contract on L2
   */
  struct DeploymentAddresses {
    address l2Factory;
    address l1Adapter;
    address l2Adapter;
    address l2UsdcImplementation;
    address l2UsdcProxy;
  }

  /**
   * @notice Deploy the L1OpUSDCAdapter on L1, the L2OpUSDCAdapter and the USDC implementation and proxy contracts on L2
   * @param _params The deploy params needed to deploy the contracts
   * @return _deploymentAddresses The addresses of the deployed contracts
   */
  function deploy(DeployParams memory _params) external returns (DeploymentAddresses memory _deploymentAddresses);
}
