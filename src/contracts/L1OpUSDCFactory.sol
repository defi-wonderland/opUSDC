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
  L1OpUSDCBridgeAdapter public immutable L1_ADAPTER_PROXY;

  /// @inheritdoc IL1OpUSDCFactory
  IUpgradeManager public immutable UPGRADE_MANAGER;

  /// @inheritdoc IL1OpUSDCFactory
  address public immutable L2_ADAPTER_PROXY;

  /// @inheritdoc IL1OpUSDCFactory
  address public immutable L2_USDC_PROXY;

  // TODO: update with some tamper data maybe?
  bytes32 internal constant SALT = bytes32('1');

  /**
   * @notice Constructs the L1 factory contract, deploys the L1 adapter and the upgrade manager and precalculates the
   * addresses of the L2 deployments
   * @param _usdc The address of the USDC contract
   * @param _owner The owner of the upgrade manager
   */
  constructor(address _usdc, address _owner) {
    // Calculate L2 factory address
    uint256 _aliasedAddressFirstNonce = 0;
    address _l2Factory = _precalculateCreateAddress(ALIASED_SELF, _aliasedAddressFirstNonce);
    // Calculate the L2 USDC proxy address
    bytes32 _l2UsdcProxyInitCodeHash = keccak256(bytes.concat(USDC_PROXY_CREATION_CODE, abi.encode(address(0))));
    L2_USDC_PROXY = _precalculateCreate2Address(SALT, _l2UsdcProxyInitCodeHash, _l2Factory);
    // Calculate the L2 adapter proxy address
    bytes32 _l2AdapterProxyInitCodeHash =
      keccak256(bytes.concat(type(ERC1967Proxy).creationCode, abi.encode(address(0), '')));
    L2_ADAPTER_PROXY = _precalculateCreate2Address(SALT, _l2AdapterProxyInitCodeHash, _l2Factory);

    // Calculate the upgrade manager using 4 as nonce since first the L1 adapter and its implementation will be deployed
    uint256 _thisNonceFourthTx = 4;
    UPGRADE_MANAGER = IUpgradeManager(_precalculateCreateAddress(address(this), _thisNonceFourthTx));

    // Deploy the L1 adapter implementation
    address _l1AdapterImplementation =
      address(new L1OpUSDCBridgeAdapter(_usdc, L2_ADAPTER_PROXY, address(UPGRADE_MANAGER), address(this)));
    // Deploy the L1 adapter proxy
    L1_ADAPTER_PROXY = L1OpUSDCBridgeAdapter(address(new ERC1967Proxy(_l1AdapterImplementation, '')));
    emit L1AdapterDeployed(address(L1_ADAPTER_PROXY), _l1AdapterImplementation);

    // Deploy the upgrade manager implementation
    address _upgradeManagerImplementation = address(new UpgradeManager(address(L1_ADAPTER_PROXY)));
    // Deploy and initialize the upgrade manager proxy
    bytes memory _initializeTx = abi.encodeWithSelector(IUpgradeManager.initialize.selector, _owner);
    UpgradeManager(address(new ERC1967Proxy(address(_upgradeManagerImplementation), _initializeTx)));
    emit UpgradeManagerDeployed(address(UPGRADE_MANAGER), _upgradeManagerImplementation);
  }

  /**
   * @notice Sends the L2 factory creation tx along with the L2 deployments to be done on it through the portal
   * @param _l1Messenger The address of the L1 messenger for the L2 Op chain
   * @param _minGasLimit The minimum gas limit for the L2 deployment
   * @dev We deploy the proxies with the 0 address as implementation and then upgrade them with the actual
   * implementation because the `CREATE2` opcode is dependent on the creation code and a different implementation
   */
  function deployL2UsdcAndAdapter(address _l1Messenger, uint32 _minGasLimit) external {
    L1_ADAPTER_PROXY.initializeNewMessenger(_l1Messenger);

    // Get the bytecode of the L2 usdc implementation
    IUpgradeManager.Implementation memory _l2UsdcImplementation = UPGRADE_MANAGER.bridgedUSDCImplementation();
    bytes memory _l2UsdcImplementationBytecode = _l2UsdcImplementation.implementation.code;
    // Get the bytecode of the he L2 adapter
    IUpgradeManager.Implementation memory _l2AdapterImplementation = UPGRADE_MANAGER.l2AdapterImplementation();
    bytes memory _l2AdapterBytecode = _l2AdapterImplementation.implementation.code;

    // Get the L2 factory init code
    bytes memory _l2FactoryCreationCode = type(L2OpUSDCFactory).creationCode;
    bytes memory _l2FactoryCArgs = abi.encode(
      SALT,
      USDC_PROXY_CREATION_CODE,
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

  // TODO: Create deployments lib

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

  /**
   * @dev Returns the address where a contract will be stored if deployed via `deployer` using
   * the `CREATE2` opcode. Any change in the `initCodeHash` or `salt` values will result in a new
   * destination address. This implementation is based on OpenZeppelin:
   * https://web.archive.org/web/20230921113703/https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/181d518609a9f006fcb97af63e6952e603cf100e/contracts/utils/Create2.sol.
   * @param salt The 32-byte random value used to create the contract address.
   * @param initCodeHash The 32-byte bytecode digest of the contract creation bytecode.
   * @param deployer The 20-byte deployer address.
   * @return computedAddress The 20-byte address where a contract will be stored.
   */
  function _precalculateCreate2Address(
    bytes32 salt,
    bytes32 initCodeHash,
    address deployer
  ) public pure returns (address computedAddress) {
    assembly ("memory-safe") {
      // |                      | ↓ ptr ...  ↓ ptr + 0x0B (start) ...  ↓ ptr + 0x20 ...  ↓ ptr + 0x40 ...   |
      // |----------------------|---------------------------------------------------------------------------|
      // | initCodeHash         |                                                        CCCCCCCCCCCCC...CC |
      // | salt                 |                                      BBBBBBBBBBBBB...BB                   |
      // | deployer             | 000000...0000AAAAAAAAAAAAAAAAAAA...AA                                     |
      // | 0xFF                 |            FF                                                             |
      // |----------------------|---------------------------------------------------------------------------|
      // | memory               | 000000...00FFAAAAAAAAAAAAAAAAAAA...AABBBBBBBBBBBBB...BBCCCCCCCCCCCCC...CC |
      // | keccak256(start, 85) |            ↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑ |
      let ptr := mload(0x40)
      mstore(add(ptr, 0x40), initCodeHash)
      mstore(add(ptr, 0x20), salt)
      mstore(ptr, deployer)
      let start := add(ptr, 0x0b)
      mstore8(start, 0xff)
      computedAddress := keccak256(start, 85)
    }
  }
}
