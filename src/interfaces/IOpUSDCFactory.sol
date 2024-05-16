// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ICreateX} from 'interfaces/external/ICreateX.sol';
import {ICrossDomainMessenger} from 'interfaces/external/ICrossDomainMessenger.sol';

interface IOpUSDCFactory {
  /**
   * @notice Deploy params needed to call the `deploy()` function
   * @param l2Messenger The address of the L2 CrossDomainMessenger
   * @param l1OpUSDCBridgeAdapterCreationCode The creation code of the `L1OpUSDCBridgeAdapter` contract
   * @param l2OpUSDCBridgeAdapterCreationCode The creation code of the `L2OpUSDCBridgeAdapter` contract
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
    address l2Messenger;
    bytes l1OpUSDCBridgeAdapterCreationCode;
    bytes l2OpUSDCBridgeAdapterCreationCode;
    bytes usdcProxyCreationCode;
    bytes usdcImplementationCreationCode;
    address owner;
    uint32 minGasLimitUsdcProxyDeploy;
    uint32 minGasLimitUsdcImplementationDeploy;
    uint32 minGasLimitL2AdapterDeploy;
    uint32 minGasLimitInitializeTxs;
    uint256 l2ChainId;
  }

  /**
   * @notice Deploy the L1OpUSDCAdapter on L1, the L2OpUSDCAdapter and the USDC implementation and proxy contracts on L2
   * @param _params The deploy params needed to deploy the contracts
   */
  function deploy(DeployParams memory _params) external;

  /**
   * @return _salt The salt used to deploy the contracts when interacting with the CreateX contract
   */
  //solhint-disable-next-line func-name-mixedcase
  function SALT() external view returns (bytes32 _salt);

  /**
   * @return _l1LinkedAdapter The address of the linked adapter on L1
   */
  //solhint-disable-next-line func-name-mixedcase
  function L1_LINKED_ADAPTER() external view returns (address _l1LinkedAdapter);

  /**
   * @return _l1CrossDomainMessenger The address of the CrossDomainMessenger contract on L1
   */
  //solhint-disable-next-line func-name-mixedcase
  function L1_CROSS_DOMAIN_MESSENGER() external view returns (ICrossDomainMessenger _l1CrossDomainMessenger);

  /**
   * @return _usdc The address of the USDC contract
   */
  //solhint-disable-next-line func-name-mixedcase
  function USDC() external view returns (address _usdc);

  /**
   * @return _l1CreateX The address of the CreateX contract on L1
   */
  //solhint-disable-next-line func-name-mixedcase
  function L1_CREATEX() external view returns (ICreateX _l1CreateX);

  /**
   * @return _l2CreateX The address of the CreateX contract on L2
   */
  //solhint-disable-next-line func-name-mixedcase
  function L2_CREATEX() external view returns (address _l2CreateX);
}
