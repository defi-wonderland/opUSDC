// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IUSDC} from './external/IUSDC.sol';

// solhint-disable func-name-mixedcase
interface IL1OpUSDCFactory {
  /**
   * @notice The struct to hold the deployments data to deploy the L2 adapter, and the L2 USDC contracts
   * @param l2AdapterOwner The address of the owner of the L2 adapter
   * @param minGasLimitCreate2Factory The minimum gas limit for the L2 factory deployment
   * @param usdcImplementationInitCode The creation code with the constructor arguments for the USDC implementation
   * @param usdcInitTxs The initialization transactions to be executed on the USDC contract. The `initialize()` first
   * init tx must not be included since it is defined in the L2 factory contract
   * @param minGasLimitDeploy The minimum gas limit for calling the `deploy` function on the L2 factory
   * @dev Only the values needed in both `deployL2FactoryAndContracts()` and `deployAdapters()` params are included
   */
  struct L2Deployments {
    address l2AdapterOwner;
    bytes usdcImplementationInitCode;
    bytes[] usdcInitTxs;
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

  /**
   * @notice Thrown when the salt for deploying the L2 factory is already used
   */
  error IL1OpUSDCFactory_SaltAlreadyUsed();

  /**
   * @notice Thrown when the factory on L2 for the given messenger is not deployed and the `deployL2USDCAndAdapter` is
   * called
   */
  error IL1OpUSDCFactory_L2FactoryNotDeployed();

  /**
   * @notice Thrown when there are no init txs provided for the USDC contract
   */
  error IL1OpUSDCFactory_NoInitTxs();

  /**
   * @notice Thrown when the 1st provided init tx's selector is not the `initialize()` function one
   */
  error IL1OpUSDCFactory_InvalidInitTx();

  /**
   * @notice Thrown if the nonce is greater than 2**64-2 while precalculating the L1 Adapter using `CREATE`
   */
  error IL1OpUSDCFactory_InvalidNonce();

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  ///////////////////////////////////////////////////////////////*/

  /**
   * @notice Sends the L2 factory creation tx along with the L2 deployments to be done on it through the messenger
   * @param _l2FactorySalt The salt for the L2 factory deployment
   * @param _l1Messenger The address of the L1 messenger for the L2 Op chain
   * @param _minGasLimitCreate2Factory The minimum gas limit for the L2 factory deployment
   * @param _l1AdapterOwner The address of the owner of the L1 adapter
   * @param _l2Deployments The deployments data for the L2 adapter, and the L2 USDC contracts
   * @return _l2Factory The address of the L2 factory
   * @return _l1Adapter The address of the L1 adapter
   * @return _l2Adapter The address of the L2 adapter
   */
  function deployL2FactoryAndContracts(
    bytes32 _l2FactorySalt,
    address _l1Messenger,
    uint32 _minGasLimitCreate2Factory,
    address _l1AdapterOwner,
    L2Deployments memory _l2Deployments
  ) external returns (address _l2Factory, address _l1Adapter, address _l2Adapter);

  /**
   * @notice Sends the L2 adapter and USDC proxy and implementation deployments tx through the messenger
   * to be executed on the l2 factory
   * @param _l1Messenger The address of the L1 messenger for the L2 Op chain
   * @param _l1AdapterOwner The address of the owner of the L1 adapter
   * @param _l2Deployments The deployments data for the L2 adapter, and the L2 USDC contracts
   * @return _l1Adapter The address of the L1 adapter
   * @return _l2Adapter The address of the L2 adapter
   */
  function deployAdapters(
    address _l1Messenger,
    address _l1AdapterOwner,
    address _l2Factory,
    L2Deployments memory _l2Deployments
  ) external returns (address _l1Adapter, address _l2Adapter);

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
   * @return _initializeSelector The selector of the `initialize()` function
   * @dev Used to check the first init tx doesn't match it since it is already defined in the L2 factory contract
   */
  function INITIALIZE_SELECTOR() external view returns (bytes4 _initializeSelector);

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
   * @notice Tracks the nonce for each L2 factory
   * @param _l2Factory The address of the L2 factory
   * @return _l2FactoryNonce The nonce of the L2 factory
   */
  function l2FactoryNonce(address _l2Factory) external view returns (uint256 _l2FactoryNonce);

  /**
   * @notice Checks if the salt has been used for deploying the L2 factory
   * @param _salt The salt for the L2 factory deployment
   * @return _isUsed Whether the salt has been used
   * @dev Is important to track this to avoid having the L2 Factory deployed in the same address on different chains,
   * which would lead to having the same addresses for L2 contracts owned by different owners
   */
  function isSaltUsed(bytes32 _salt) external view returns (bool _isUsed);
}
