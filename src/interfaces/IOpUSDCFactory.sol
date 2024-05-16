// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ICreateX} from 'interfaces/external/ICreateX.sol';
import {ICrossDomainMessenger} from 'interfaces/external/ICrossDomainMessenger.sol';

interface IOpUSDCFactory {
  /**
   * @notice Deploy params needed to call the `deploy()` function
   * @param l1Messenger The address of the L1 CrossDomainMessenger
   * @param l2Messenger The address of the L2 CrossDomainMessenger
   * @param l1dapterCreationCode The creation code of the `L1OpUSDCBridgeAdapter` contract
   * @param l2AdapterCreationCode The creation code of the `L2OpUSDCBridgeAdapter` contract
   * @param usdcProxyCreationCode The creation code of the USDC proxy contract
   * @param usdcImplementationCreationCode The creation code of the USDC implementation contract
   * @param owner The owner of the `L1OpUSDCBridgeAdapter` contract
   * @param minGasLimitUsdcProxyDeploy The minimum gas limit for the USDC proxy contract deploy on L2
   * @param minGasLimitUsdcImplementationDeploy The minimum gas limit for the USDC implementation contract deploy on L2
   * @param minGasLimitL2AdapterDeploy The minimum gas limit for the L2 adapter contract deploy on L2
   * @param minGasLimitInitializeTxs The minimum gas limit for the initialize transactions over the USDC implementation
   * contract on L2
   * @param l2ChainId The chain ID of the L2 network
   */
  struct DeployParams {
    ICrossDomainMessenger l1Messenger;
    address l2Messenger;
    bytes l1AdapterCreationCode;
    bytes l2AdapterCreationCode;
    bytes usdcImplementationCreationCode;
    bytes usdcProxyCreationCode;
    address owner;
    uint32 minGasLimitUsdcImplementationDeploy;
    uint32 minGasLimitUsdcProxyDeploy;
    uint32 minGasLimitL2AdapterDeploy;
    uint32 minGasLimitInitTxs;
    uint256 l2ChainId;
  }

  /**
   * @notice Deployment addresses of the contracts deployed by the `deploy()` function
   * @param l1Adapter The address of the L1OpUSDCAdapter contract
   * @param l2Adapter The address of the L2OpUSDCAdapter contract
   * @param l2UsdcImplementation The address of the USDC implementation contract on L2
   * @param l2UsdcProxy The address of the USDC proxy contract on L2
   */
  struct DeploymentAddresses {
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

  /**
   * @return _salt The salt used to deploy the contracts when interacting with the CreateX contract
   */
  //solhint-disable-next-line func-name-mixedcase
  function SALT() external view returns (bytes32 _salt);

  /**
   * @return _usdc The address of the USDC contract
   */
  //solhint-disable-next-line func-name-mixedcase
  function USDC() external view returns (address _usdc);

  /**
   * @return _createX The CreateX contract instance
   */
  //solhint-disable-next-line func-name-mixedcase
  function CREATEX() external view returns (ICreateX _createX);
}
