// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC1967Proxy} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import {L1OpUSDCBridgeAdapter} from 'contracts/L1OpUSDCBridgeAdapter.sol';
import {L2OpUSDCFactory} from 'contracts/L2OpUSDCFactory.sol';
import {UpgradeManager} from 'contracts/UpgradeManager.sol';
import {AddressAliasHelper} from 'contracts/utils/AddressAliasHelper.sol';
import {USDC_PROXY_CREATION_CODE} from 'contracts/utils/USDCProxyCreationCode.sol';
import {IL1OpUSDCFactory} from 'interfaces/IL1OpUSDCFactory.sol';
import {IUpgradeManager} from 'interfaces/IUpgradeManager.sol';
import {ICrossDomainMessenger} from 'interfaces/external/ICrossDomainMessenger.sol';
import {IOptimismPortal} from 'interfaces/external/IOptimismPortal.sol';

/**
 * @title L1OpUSDCFactory
 * @notice Factory contract to deploy and setup the `L1OpUSDCBridgeAdapter` and `UpgradeManager` contracts on L1, and
 * L2OpUSDCFactory on L2 - setting up the L2 deployments on a single transaction.
 */
contract L1OpUSDCFactory is IL1OpUSDCFactory {
  using AddressAliasHelper for address;

  /// @notice Zero value constant to be used on portal interaction
  uint256 internal constant _ZERO_VALUE = 0;

  /// @notice Zero address constant to be used on portal interaction
  address internal constant _ZERO_ADDRESS = address(0);

  /// @notice Flag to indicate that the tx represents a contract creation when interacting with the portal
  bool internal constant _IS_CREATION = true;

  /// @inheritdoc IL1OpUSDCFactory
  address public constant L2_MESSENGER = 0x4200000000000000000000000000000000000007;

  /// @inheritdoc IL1OpUSDCFactory
  address public immutable ALIASED_SELF = address(this).applyL1ToL2Alias();

  /// @inheritdoc IL1OpUSDCFactory
  address public immutable L1_ADAPTER;

  /// @inheritdoc IL1OpUSDCFactory
  IUpgradeManager public immutable UPGRADE_MANAGER;

  /// @inheritdoc IL1OpUSDCFactory
  address public immutable L2_ADAPTER_IMPLEMENTATION;

  /// @inheritdoc IL1OpUSDCFactory
  address public immutable L2_ADAPTER_PROXY;

  /// @inheritdoc IL1OpUSDCFactory
  address public immutable L2_USDC_PROXY;

  /// @inheritdoc IL1OpUSDCFactory
  address public immutable L2_USDC_IMPLEMENTATION;

  /// @inheritdoc IL1OpUSDCFactory
  mapping(address _l1Messenger => bool _deployed) public isMessengerDeployed;

  /**
   * @notice Constructs the L1 factory contract, deploys the L1 adapter and the upgrade manager and precalculates the
   * addresses of the L2 deployments
   * @param _usdc The address of the USDC contract
   * @param _owner The owner of the upgrade manager
   */
  constructor(address _usdc, address _owner) {
    // Calculate L1 adapter
    uint256 _thisNonceFirstTx = 1;
    L1_ADAPTER = _precalculateCreateAddress(address(this), _thisNonceFirstTx);

    // Calculate L2 factory address
    uint256 _aliasedAddressFirstNonce = 0;
    address _l2Factory = _precalculateCreateAddress(ALIASED_SELF, _aliasedAddressFirstNonce);
    // Calculate the L2 deployments using the L2 factory
    uint256 _l2FactoryFirstNonce = 1;
    L2_USDC_IMPLEMENTATION = _precalculateCreateAddress(_l2Factory, _l2FactoryFirstNonce);
    uint256 _l2FactorySecondNonce = 2;
    L2_USDC_PROXY = _precalculateCreateAddress(_l2Factory, _l2FactorySecondNonce);
    uint256 _l2FactoryThirdNonce = 3;
    L2_ADAPTER_IMPLEMENTATION = _precalculateCreateAddress(_l2Factory, _l2FactoryThirdNonce);
    uint256 _l2FactoryFourthNonce = 4;
    L2_ADAPTER_PROXY = _precalculateCreateAddress(_l2Factory, _l2FactoryFourthNonce);

    // Calculate the upgrade manager using 3 as nonce since first the L1 adapter and its implementation will be deployed
    uint256 _thisNonceThirdTx = 3;
    UPGRADE_MANAGER = IUpgradeManager(_precalculateCreateAddress(address(this), _thisNonceThirdTx));

    // Deploy the L1 adapter
    new L1OpUSDCBridgeAdapter(_usdc, L2_ADAPTER_PROXY, address(UPGRADE_MANAGER), address(this));
    emit L1AdapterDeployed(L1_ADAPTER);

    // Deploy the upgrade manager implementation
    address _upgradeManagerImplementation = address(new UpgradeManager(L1_ADAPTER));
    // Deploy and initialize the upgrade manager proxy
    bytes memory _initializeTx = abi.encodeWithSelector(IUpgradeManager.initialize.selector, _owner);
    UpgradeManager(address(new ERC1967Proxy(address(_upgradeManagerImplementation), _initializeTx)));
    emit UpgradeManagerDeployed(address(UPGRADE_MANAGER));
  }

  /**
   * @notice Sends the L2 factory creation tx along with the L2 deployments to be done on it through the portal
   * @param _l1Messenger The address of the L1 messenger for the L2 Op chain
   * @param _minGasLimit The minimum gas limit for the L2 deployment
   */
  function deployL2UsdcAndAdapter(address _l1Messenger, uint32 _minGasLimit) external {
    if (isMessengerDeployed[_l1Messenger]) revert IL1OpUSDCFactory_MessengerAlreadyDeployed();
    if (IUpgradeManager(UPGRADE_MANAGER).messengerDeploymentExecutor(_l1Messenger) != msg.sender) {
      revert IL1OpUSDCFactory_NotExecutor();
    }

    isMessengerDeployed[_l1Messenger] = true;

    // TODO: When using `CREATE2` to deploy on L2, we'll need to deploy the proxies with the 0 address as implementation
    // and then upgrade them with the actual implementation. This is because the `CREATE2` opcode is dependant on the
    // creation code and a different implementation would result in a different address.
    // Get the L2 usdc proxy init code
    bytes memory _usdcProxyCArgs = abi.encode(L2_USDC_IMPLEMENTATION);
    bytes memory _usdcProxyInitCode = bytes.concat(USDC_PROXY_CREATION_CODE, _usdcProxyCArgs);

    // Get the bytecode of the L2 usdc implementation
    IUpgradeManager.Implementation memory _l2UsdcImplementation = UPGRADE_MANAGER.bridgedUSDCImplementation();
    bytes memory _l2UsdcImplementationBytecode = _l2UsdcImplementation.implementation.code;
    // Get the bytecode of the he L2 adapter
    IUpgradeManager.Implementation memory _l2AdapterImplementation = UPGRADE_MANAGER.l2AdapterImplementation();
    bytes memory _l2AdapterBytecode = _l2AdapterImplementation.implementation.code;

    // Get the L2 factory init code
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
