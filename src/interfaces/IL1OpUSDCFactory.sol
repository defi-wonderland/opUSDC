// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IUSDC} from './external/IUSDC.sol';

// solhint-disable func-name-mixedcase
interface IL1OpUSDCFactory {
  /**
   * @notice The struct to hold the deployments data to deploy the L2 Factory, L2 adapter, and the L2 USDC contracts
   * @param l2AdapterOwner The address of the owner of the L2 adapter
   * @param minGasLimitCreate2Factory The minimum gas limit for the L2 factory deployment
   * @param usdcImplementationInitCode The creation code with the constructor arguments for the USDC implementation
   * @param usdcInitTxs The initialization transactions to be executed on the USDC contract. The `initialize()` first
   * init tx must not be included since it is defined in the L2 factory contract
   * @param minGasLimitDeploy The minimum gas limit for calling the deploying the L2 Factory, L2 adapter, and L2 USDC
   */
  struct L2Deployments {
    address l2AdapterOwner;
    bytes usdcImplementationInitCode;
    bytes[] usdcInitTxs;
    uint32 minGasLimitFactory;
    uint32 minGasLimitDeploy;
  }

  /*///////////////////////////////////////////////////////////////
                            EVENTS
  ///////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when the `L1OpUSDCBridgeAdapter` is deployed
   * @param _l1Adapter The address of the L1 adapter
   */
  event L1AdapterDeployed(address _l1Adapter);

  /*///////////////////////////////////////////////////////////////
                            ERRORS
  ///////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when the `initialize()` tx is provided as the first init tx for the USDC contract
   */
  error IL1OpUSDCFactory_NoInitializeTx();

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  ///////////////////////////////////////////////////////////////*/

  /**
   * @notice Deploys the L1 Adapter, and sends the deployment txs for the L2 factory, L2 adapter and the L2 USDC through
   * the L1 messenger
   * @param _l1Messenger The address of the L1 messenger for the L2 Op chain
   * @param _l1AdapterOwner The address of the owner of the L1 adapter
   * @param _l2Deployments The deployments data for the L2 adapter, and the L2 USDC contracts
   * @return _l1Adapter The address of the L1 adapter
   * @return _l2Factory The address of the L2 factory
   * @return _l2Adapter The address of the L2 adapter
   */
  function deploy(
    address _l1Messenger,
    address _l1AdapterOwner,
    L2Deployments calldata _l2Deployments
  ) external returns (address _l1Adapter, address _l2Factory, address _l2Adapter);

  /*///////////////////////////////////////////////////////////////
                            VARIABLES
  ///////////////////////////////////////////////////////////////*/

  /**
   * @return _l2Messenger The address of the L2 messenger
   */
  function L2_MESSENGER() external view returns (address _l2Messenger);

  /**
   * @return _l2Create2Deployer The address of the `create2Deployer` contract on L2
   */
  function L2_CREATE2_DEPLOYER() external view returns (address _l2Create2Deployer);

  /**
   * @return _usdc The address of USDC on L1
   */
  function USDC() external view returns (IUSDC _usdc);

  /**
   * @return _name The name of the USDC token
   * @dev If the 3rd party team wants to update the name, it can be done on the `initialize2()` 2nd init tx
   */
  function USDC_NAME() external view returns (string memory _name);

  /**
   * @return _symbol The symbol of the USDC token
   */
  function USDC_SYMBOL() external view returns (string memory _symbol);

  /**
   * @return _deploymentsSaltCounter The counter for the deployments salt to be used on the L2 factory deployment
   */
  function deploymentsSaltCounter() external view returns (uint256 _deploymentsSaltCounter);
}
