// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC1967Proxy} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import {L1OpUSDCBridgeAdapter} from 'contracts/L1OpUSDCBridgeAdapter.sol';
import {L2OpUSDCFactory} from 'contracts/L2OpUSDCFactory.sol';
import {UpgradeManager} from 'contracts/UpgradeManager.sol';
import {AddressAliasHelper} from 'contracts/utils/AddressAliasHelper.sol';
import {USDC_PROXY_CREATION_CODE} from 'contracts/utils/USDCProxyCreationCode.sol';
import {IL1OpUSDCBridgeAdapter} from 'interfaces/IL1OpUSDCBridgeAdapter.sol';
import {IL1OpUSDCFactory} from 'interfaces/IL1OpUSDCFactory.sol';
import {IUpgradeManager} from 'interfaces/IUpgradeManager.sol';
import {ICrossDomainMessenger} from 'interfaces/external/ICrossDomainMessenger.sol';
import {IOptimismPortal} from 'interfaces/external/IOptimismPortal.sol';

/**
 * @title L1OpUSDCFactory
 * @notice Factory contract to deploy and setup the `L1OpUSDCBridgeAdapter` contract on L1, the
 * `L2OpUSDCBridgeAdapter` and USDC proxy and implementation contracts on L2 on a single transaction.
 */
contract L1OpUSDCFactory is IL1OpUSDCFactory {
  uint256 internal constant _ZERO_VALUE = 0;

  address internal constant _ZERO_ADDRESS = address(0);

  bool internal constant _IS_CREATION = true;

  address public constant L2_MESSENGER = 0x4200000000000000000000000000000000000007;

  address public immutable ALIASED_SELF = AddressAliasHelper.applyL1ToL2Alias(address(this));

  address public immutable L1_ADAPTER;

  IUpgradeManager public immutable UPGRADE_MANAGER;

  address public immutable L2_ADAPTER;

  address public immutable L2_USDC_PROXY;

  address public immutable L2_USDC_IMPLEMENTATION;

  constructor(address _usdc, address _owner) {
    // Calculate l1 adapter
    uint256 _thisNonceFirstTx = 1;
    L1_ADAPTER = _precalculateCreateAddress(address(this), _thisNonceFirstTx);

    // Calculate l2 factory address
    uint256 _aliasedAddressFirstNonce = 0;
    address _l2Factory = _precalculateCreateAddress(ALIASED_SELF, _aliasedAddressFirstNonce);
    // Calculate the l2 deployments using the l2 factory
    uint256 _l2FactoryFirstNonce = 1;
    L2_USDC_IMPLEMENTATION = _precalculateCreateAddress(_l2Factory, _l2FactoryFirstNonce);
    uint256 _l2FactorySecondNonce = 2;
    L2_USDC_PROXY = _precalculateCreateAddress(_l2Factory, _l2FactorySecondNonce);
    uint256 _l2FactoryThirdNonce = 3;
    L2_ADAPTER = _precalculateCreateAddress(_l2Factory, _l2FactoryThirdNonce);

    // Calculate the upgrade manager using 3 as nonce since first the l1 adapter and its implementation will be deployed
    uint256 _thisNonceThirdTx = 3;
    UPGRADE_MANAGER = IUpgradeManager(_precalculateCreateAddress(address(this), _thisNonceThirdTx));

    // Deploy the L1 adapter
    new L1OpUSDCBridgeAdapter(_usdc, L2_ADAPTER, address(UPGRADE_MANAGER), address(this));
    emit L1AdapterDeployed(L1_ADAPTER);

    // Deploy the upgrade manager implementation
    address _upgradeManagerImplementation = address(new UpgradeManager(L1_ADAPTER));
    // Deploy and initialize the upgrade manager proxy
    bytes memory _initializeTx = abi.encodeWithSelector(IUpgradeManager.initialize.selector, _owner);
    UpgradeManager(address(new ERC1967Proxy(address(_upgradeManagerImplementation), _initializeTx)));
    emit UpgradeManagerDeployed(address(UPGRADE_MANAGER));
  }

  /**
   * @inheritdoc IL1OpUSDCFactory
   */
  function deployL2UsdcAndAdapter(address _l1Messenger, uint32 _minGasLimit) external {
    // Get the l2 usdc proxy init code
    bytes memory _usdcProxyCArgs = abi.encode(L2_USDC_IMPLEMENTATION);
    bytes memory _usdcProxyInitCode = bytes.concat(USDC_PROXY_CREATION_CODE, _usdcProxyCArgs);

    // Get the bytecode of the l2 usdc implementation and the l2 adapter
    IUpgradeManager.Implementation memory _l2UsdcImplementation = UPGRADE_MANAGER.bridgedUSDCImplementation();
    bytes memory _l2UsdcImplementationBytecode = _l2UsdcImplementation.implementation.code;

    IUpgradeManager.Implementation memory _l2AdapterImplementation = UPGRADE_MANAGER.l2AdapterImplementation();
    bytes memory _l2AdapterBytecode = _l2AdapterImplementation.implementation.code;

    // Get the l2 factory init code
    bytes memory _l2FactoryCreationCode = type(L2OpUSDCFactory).creationCode;
    bytes memory _l2FactoryCArgs = abi.encode(
      _usdcProxyInitCode,
      _l2UsdcImplementationBytecode,
      _l2UsdcImplementation.initTxs,
      _l2AdapterBytecode,
      _l2AdapterImplementation.initTxs
    );

    bytes memory _l2FactoryInitCode = bytes.concat(_l2FactoryCreationCode, _l2FactoryCArgs);

    // Deploy L2 op usdc factory through portal
    IOptimismPortal _portal = ICrossDomainMessenger(_l1Messenger).portal();
    _portal.depositTransaction(_ZERO_ADDRESS, _ZERO_VALUE, _minGasLimit, _IS_CREATION, _l2FactoryInitCode);
  }

  /**
   * @notice Precalculates the address of a contract that will be deployed thorugh `CREATE` opcode
   * @dev It only works if the for nonces between 0 and 127, which is enough for this use case
   * @param _deployer The deployer address
   * @param _nonce The next nonce of the deployer address
   * @return _precalculatedAddress The address where the contract will be stored
   */
  function _precalculateCreateAddress(
    address _deployer,
    uint256 _nonce
  ) internal pure returns (address _precalculatedAddress) {
    bytes memory data;
    bytes1 len = bytes1(0x94);

    // The integer zero is treated as an empty byte string and therefore has only one length prefix,
    // 0x80, which is calculated via 0x80 + 0.
    if (_nonce == 0x00) {
      data = abi.encodePacked(bytes1(0xd6), len, _deployer, bytes1(0x80));
    }
    // A one-byte integer in the [0x00, 0x7f] range uses its own value as a length prefix, there is no
    // additional "0x80 + length" prefix that precedes it.
    else if (_nonce <= 0x7f) {
      data = abi.encodePacked(bytes1(0xd6), len, _deployer, uint8(_nonce));
    }

    _precalculatedAddress = address(uint160(uint256(keccak256(data))));
  }
}
