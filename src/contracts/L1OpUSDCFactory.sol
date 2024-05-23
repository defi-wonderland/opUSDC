// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {L1OpUSDCBridgeAdapter} from 'contracts/L1OpUSDCBridgeAdapter.sol';
import {L2OpUSDCFactory} from 'contracts/L2OpUSDCFactory.sol';
import {UpgradeManager} from 'contracts/UpgradeManager.sol';
import {AddressAliasHelper} from 'contracts/utils/AddressAliasHelper.sol';
import {CreateDeployer} from 'contracts/utils/CreateDeployer.sol';
import {USDCInitTxs} from 'contracts/utils/USDCInitTxs.sol';

import 'forge-std/Test.sol';
import {IL1OpUSDCBridgeAdapter} from 'interfaces/IL1OpUSDCBridgeAdapter.sol';
import {IL1OpUSDCFactory} from 'interfaces/IL1OpUSDCFactory.sol';

import {BytecodeDeployer} from 'contracts/BytecodeDeployer.sol';
import {IUpgradeManager} from 'interfaces/IUpgradeManager.sol';
import {ICreateX} from 'interfaces/external/ICreateX.sol';
import {ICrossDomainMessenger} from 'interfaces/external/ICrossDomainMessenger.sol';
import {IOptimismPortal} from 'interfaces/external/IOptimismPortal.sol';
import {IUSDC} from 'interfaces/external/IUSDC.sol';

/**
 * @title L1OpUSDCFactory
 * @notice Factory contract to deploy and setup the `L1OpUSDCBridgeAdapter` contract on L1, the
 * `L2OpUSDCBridgeAdapter` and USDC proxy and implementation contracts on L2 on a single transaction.
 */
contract L1OpUSDCFactory is CreateDeployer, IL1OpUSDCFactory {
  uint256 internal constant _ZERO_VALUE = 0;

  address internal constant _ZERO_ADDRESS = address(0);

  bool internal constant _IS_CREATION = true;

  address public constant L2_MESSENGER = 0x4200000000000000000000000000000000000007;

  IL1OpUSDCBridgeAdapter public immutable L1_ADAPTER;

  IUpgradeManager public immutable UPGRADE_MANAGER;

  IUSDC public immutable USDC;

  address public immutable L2_FACTORY;

  address public immutable L2_ADAPTER;

  address public immutable L2_USDC_PROXY;

  address public immutable L2_USDC_IMPLEMENTATION;

  address public immutable ALIASED_SELF = AddressAliasHelper.applyL1ToL2Alias(address(this));

  constructor(address _usdc, address _owner) {
    USDC = IUSDC(_usdc);
    // Calculate l1 adapter
    uint256 _nonceFirstTx = 1;
    L1_ADAPTER = IL1OpUSDCBridgeAdapter(computeCreateAddress(address(this), _nonceFirstTx));

    // Calculate l2 factory and l2 deplloyments
    L2_FACTORY = computeCreateAddress(ALIASED_SELF, 0);
    L2_USDC_IMPLEMENTATION = computeCreateAddress(L2_FACTORY, 1);
    L2_USDC_PROXY = computeCreateAddress(L2_FACTORY, 2);
    L2_ADAPTER = computeCreateAddress(L2_FACTORY, 3);

    // Calculate the upgrade manager using 2 as nonce since the first 2 txs will deploy the l1 adapter
    UPGRADE_MANAGER = IUpgradeManager(computeCreateAddress(address(this), 2));

    // Deploy the L1 adapter
    new L1OpUSDCBridgeAdapter(_usdc, L2_ADAPTER, address(UPGRADE_MANAGER), address(this));
    emit L1AdapterDeployed(address(L1_ADAPTER));

    // Deploy and initialize the upgrade manager
    new UpgradeManager(address(L1_ADAPTER));
    emit UpgradeManagerDeployed(address(UPGRADE_MANAGER));
    // TODO: initialize
    // UPGRADE_MANAGER.initialize(_owner);
  }

  /**
   * @inheritdoc IL1OpUSDCFactory
   */
  function deployL2UsdcAndAdapter(address _l1Messenger, uint32 _minGasLimit) external {
    // Get the l2 factory init code
    // TODO: get the impl codes
    bytes memory _l2FactoryCreationCode = type(L2OpUSDCFactory).creationCode;

    // TODO: do this or get the creation code directly?
    bytes memory _usdcProxyBytecode = address(USDC).code;

    bytes memory _l2AdapterBytecode = UPGRADE_MANAGER.l2AdapterImplementation().code;
    bytes memory _l2UsdcImplementationBytecode = UPGRADE_MANAGER.bridgedUSDCImplementation().code;

    bytes memory _l2FactoryCArgs = abi.encode(_l2AdapterBytecode, _usdcProxyBytecode, _l2UsdcImplementationBytecode);
    bytes memory _l2FactoryInitCode = bytes.concat(_l2FactoryCreationCode, _l2FactoryCArgs);

    // Deploy L2 op usdc factory through portal
    IOptimismPortal _portal = ICrossDomainMessenger(_l1Messenger).portal();
    _portal.depositTransaction(_ZERO_ADDRESS, _ZERO_VALUE, _minGasLimit, _IS_CREATION, _l2FactoryInitCode);
  }
}
