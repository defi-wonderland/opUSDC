// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IUSDC} from './external/IUSDC.sol';

// solhint-disable func-name-mixedcase
interface IL1OpUSDCFactory {
  /**
   * @notice The struct to hold the deployments data to deploy the L2 Factory, L2 adapter, and the L2 USDC contracts
   * @param l2AdapterOwner The address of the owner of the L2 adapter
   * @param usdcImplAddr The address of the USDC implementation on L2 to connect the proxy to
   * @param minGasLimitDeploy The minimum gas limit for deploying the L2 Deploy, L2 adapter, and L2 USDC proxy
   * @param usdcInitTxs The initialization transactions to be executed on the USDC contract. The `initialize()` first
   * init tx must not be included since it is defined in the L2 factory contract
   */
  struct L2Deployments {
    address l2AdapterOwner;
    address usdcImplAddr;
    uint32 minGasLimitDeploy;
    bytes[] usdcInitTxs;
  }

  /*///////////////////////////////////////////////////////////////
                            EVENTS
  ///////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when the `L1OpUSDCBridgeAdapter` is deployed
   * @param _l1Adapter The address of the L1 adapter
   * @param _l2Factory The address of the L2 factory where L2 contract will be deployed
   * @param _l2Adapter The address of the L2 adapter where L2 contract will be deployed
   */
  event ProtocolDeployed(address _l1Adapter, address _l2Factory, address _l2Adapter);

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
   * @param _chainName The name of the L2 Op chain
   * @param _l2Deployments The deployments data for the L2 adapter, and the L2 USDC contracts
   * @return _l1Adapter The address of the L1 adapter
   * @return _l2Factory The address of the L2 factory
   * @return _l2Adapter The address of the L2 adapter
   * @dev It can fail on L2 due to a gas miscalculation, but in that case the tx can be replayed. It only deploys 1 L2
   * factory per L2 deployments, to make sure the nonce is being tracked correctly while precalculating addresses
   * @dev The implementation of the USDC contract needs to be deployed on L2 before this is called
   * Then set the `usdcImplAddr` in the L2Deployments struct to the address of the deployed USDC implementation contract
   *
   * @dev IMPORTANT!!!!
   * The _l2Deployments.usdcInitTxs must be manually entered to correctly initialize the USDC contract on L2.
   * If a function is not included in the init txs, it could lead to potential attack vectors.
   * We currently hardcode the `initialize()` function in the L2 factory contract, to correctly configure the setup
   * You must provide the following init txs:
   * - initalizeV2
   * - initilizeV2_1
   * - initializeV2_2
   *
   * It is also important to note that circle may add more init functions in future implementations
   * This is up to the deployer to check and be sure all init transactions are included
   */
  function deploy(
    address _l1Messenger,
    address _l1AdapterOwner,
    string calldata _chainName,
    L2Deployments calldata _l2Deployments
  ) external returns (address _l1Adapter, address _l2Factory, address _l2Adapter);

  /*///////////////////////////////////////////////////////////////
                            VARIABLES
  ///////////////////////////////////////////////////////////////*/

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
