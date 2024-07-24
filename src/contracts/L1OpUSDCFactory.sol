// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {L1OpUSDCBridgeAdapter} from 'contracts/L1OpUSDCBridgeAdapter.sol';
import {IL1OpUSDCFactory} from 'interfaces/IL1OpUSDCFactory.sol';
import {IL2OpUSDCDeploy} from 'interfaces/IL2OpUSDCDeploy.sol';

import {IUSDC} from 'interfaces/external/IUSDC.sol';
import {CrossChainDeployments} from 'libraries/CrossChainDeployments.sol';

/**
 * @title L1OpUSDCFactory
 * @notice Factory contract to deploy and setup the `L1OpUSDCBridgeAdapter` contract on L1, and
 * triggers the deployment of the L2 factory, L2 adapter, and L2 USDC contracts.
 * @dev The salt is always different for each deployed instance of this contract on the L1 Factory, and the L2 contracts
 * are deployed with `CREATE` to guarantee that the addresses are unique among all the L2s, so we avoid a scenario where
 * L2 contracts have the same address on different L2s when triggered by different owners.
 */
contract L1OpUSDCFactory is IL1OpUSDCFactory {
  /// @inheritdoc IL1OpUSDCFactory
  address public constant L2_CREATE2_DEPLOYER = 0x13b0D85CcB8bf860b6b79AF3029fCA081AE9beF2;

  /// @inheritdoc IL1OpUSDCFactory
  string public constant USDC_NAME = 'Bridged USDC';

  /// @inheritdoc IL1OpUSDCFactory
  string public constant USDC_SYMBOL = 'USDC.e';

  /// @notice The selector of the `initialize(string,string,string,uint8,address,address,address,address)` function.
  /// @dev Used to check the first init tx doesn't match it since it is already defined in the L2 factory contract
  bytes4 internal constant _INITIALIZE_SELECTOR = 0x3357162b;

  /// @notice The L2 Adapter is the second contract to be deployed on the L2 factory so its nonce is 2
  uint256 internal constant _L2_ADAPTER_DEPLOYMENT_NONCE = 2;

  /// @inheritdoc IL1OpUSDCFactory
  IUSDC public immutable USDC;

  /// @inheritdoc IL1OpUSDCFactory
  uint256 public deploymentsSaltCounter;

  /**
   * @notice Constructs the L1 factory contract
   * @param _usdc The address of the USDC contract
   */
  constructor(address _usdc) {
    USDC = IUSDC(_usdc);
  }

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
   */
  function deploy(
    address _l1Messenger,
    address _l1AdapterOwner,
    string calldata _chainName,
    L2Deployments calldata _l2Deployments
  ) external returns (address _l1Adapter, address _l2Factory, address _l2Adapter) {
    // Checks that the first init tx selector is not equal to the `initialize()` function since  we manually
    // construct this function on the L2 factory contract
    if (bytes4(_l2Deployments.usdcInitTxs[0]) == _INITIALIZE_SELECTOR) revert IL1OpUSDCFactory_NoInitializeTx();

    // Update the salt counter so the L2 factory is deployed with a different salt to a different address and get it
    uint256 _currentNonce = ++deploymentsSaltCounter;

    // Precalculate the l1 adapter
    _l1Adapter = CrossChainDeployments.precalculateCreateAddress(address(this), _currentNonce);

    // Get the L1 USDC naming and decimals to ensure they are the same on the L2, guaranteeing the same standard
    IL2OpUSDCDeploy.USDCInitializeData memory _usdcInitializeData = IL2OpUSDCDeploy.USDCInitializeData(
      string.concat(USDC_NAME, ' ', '(', _chainName, ')'), USDC_SYMBOL, USDC.currency(), USDC.decimals()
    );
    // Use the nonce as salt to ensure always a different salt since the nonce is always increasing
    bytes32 _salt = bytes32(_currentNonce);
    // Get the L2 factory init code and precalculate its address
    bytes memory _l2FactoryCArgs = abi.encode(
      _l1Adapter,
      _l2Deployments.l2AdapterOwner,
      _l2Deployments.usdcImplAddr,
      _usdcInitializeData,
      _l2Deployments.usdcInitTxs
    );

    // Send the L2 factory deployment tx
    _l2Factory = CrossChainDeployments.deployL2Factory(
      _l2FactoryCArgs, _salt, _l1Messenger, L2_CREATE2_DEPLOYER, _l2Deployments.minGasLimitDeploy
    );

    // Precalculate the L2 adapter address
    _l2Adapter = CrossChainDeployments.precalculateCreateAddress(_l2Factory, _L2_ADAPTER_DEPLOYMENT_NONCE);
    // Deploy the L1 adapter
    address(new L1OpUSDCBridgeAdapter(address(USDC), _l1Messenger, _l2Adapter, _l1AdapterOwner));

    emit ProtocolDeployed(_l1Adapter, _l2Factory, _l2Adapter);
  }
}
