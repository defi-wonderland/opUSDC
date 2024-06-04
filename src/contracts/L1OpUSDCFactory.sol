// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC1967Proxy} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import {L1OpUSDCBridgeAdapter} from 'contracts/L1OpUSDCBridgeAdapter.sol';
import {L2OpUSDCFactory} from 'contracts/L2OpUSDCFactory.sol';
import {UpgradeManager} from 'contracts/UpgradeManager.sol';
import {USDC_PROXY_CREATION_CODE} from 'contracts/utils/USDCProxyCreationCode.sol';
import {IL1OpUSDCFactory} from 'interfaces/IL1OpUSDCFactory.sol';
import {IUpgradeManager} from 'interfaces/IUpgradeManager.sol';
import {ICreate2Deployer} from 'interfaces/external/ICreate2Deployer.sol';
import {ICrossDomainMessenger} from 'interfaces/external/ICrossDomainMessenger.sol';

/**
 * @title L1OpUSDCFactory
 * @notice Factory contract to deploy and setup the `L1OpUSDCBridgeAdapter` and `UpgradeManager` contracts on L1, and
 * precalculates the addresses of the L2 deployments to be done on the L2 factory.
 */
contract L1OpUSDCFactory is IL1OpUSDCFactory {
  /// @notice Zero value constant to be used on portal interaction
  uint256 internal constant _ZERO_VALUE = 0;

  /// @inheritdoc IL1OpUSDCFactory
  address public constant L2_MESSENGER = 0x4200000000000000000000000000000000000007;

  /// @inheritdoc IL1OpUSDCFactory
  address public constant L2_CREATE2_DEPLOYER = 0x13b0D85CcB8bf860b6b79AF3029fCA081AE9beF2;

  /// @inheritdoc IL1OpUSDCFactory
  address public immutable L2_FACTORY;

  /// @inheritdoc IL1OpUSDCFactory
  L1OpUSDCBridgeAdapter public immutable L1_ADAPTER_PROXY;

  /// @inheritdoc IL1OpUSDCFactory
  IUpgradeManager public immutable UPGRADE_MANAGER;

  /// @inheritdoc IL1OpUSDCFactory
  address public immutable L2_ADAPTER_PROXY;

  /// @inheritdoc IL1OpUSDCFactory
  address public immutable L2_USDC_PROXY;

  /// @notice Salt value to be used to deploy the L2 contracts on the L2 factory
  bytes32 internal immutable _SALT;

  /// @inheritdoc IL1OpUSDCFactory
  mapping(address _l1Messenger => bool _deployed) public isMessengerDeployed;

  /**
   * @notice Constructs the L1 factory contract, deploys the L1 adapter and the upgrade manager and precalculates the
   * addresses of the L2 deployments
   * @param _usdc The address of the USDC contract
   * @param _owner The owner of the upgrade manager
   */
  constructor(address _usdc, bytes32 _salt, address _owner) {
    // The WETH predeploy address on the OP Chains
    address _wethL2 = 0x4200000000000000000000000000000000000006;
    _SALT = _salt;
    bytes memory _emptyInitTx = '';

    // Calculate L2 factory address
    bytes memory _l2FactoryCreationCode = type(L2OpUSDCFactory).creationCode;
    bytes memory _l2FactoryCArgs = abi.encode(_SALT, address(this));
    bytes32 _l2FactoryInitCodeHash = keccak256(bytes.concat(_l2FactoryCreationCode, _l2FactoryCArgs));
    L2_FACTORY = _precalculateCreate2Address(_SALT, _l2FactoryInitCodeHash, L2_CREATE2_DEPLOYER);

    // Calculate the L2 USDC proxy address
    bytes32 _l2UsdcProxyInitCodeHash = keccak256(bytes.concat(USDC_PROXY_CREATION_CODE, abi.encode(_wethL2)));
    L2_USDC_PROXY = _precalculateCreate2Address(_SALT, _l2UsdcProxyInitCodeHash, L2_FACTORY);

    // Calculate the L2 adapter proxy address
    bytes32 _l2AdapterProxyInitCodeHash =
      keccak256(bytes.concat(type(ERC1967Proxy).creationCode, abi.encode(_wethL2, _emptyInitTx)));
    L2_ADAPTER_PROXY = _precalculateCreate2Address(_SALT, _l2AdapterProxyInitCodeHash, L2_FACTORY);

    // Calculate the upgrade manager using 4 as nonce since first the L1 adapter and its implementation will be deployed
    uint256 _thisNonceFourthTx = 4;
    UPGRADE_MANAGER = IUpgradeManager(_precalculateCreateAddress(address(this), _thisNonceFourthTx));

    // Deploy the L1 adapter implementation
    address _l1AdapterImplementation =
      address(new L1OpUSDCBridgeAdapter(_usdc, L2_ADAPTER_PROXY, address(UPGRADE_MANAGER), address(this)));
    // Deploy the L1 adapter proxy
    L1_ADAPTER_PROXY = L1OpUSDCBridgeAdapter(address(new ERC1967Proxy(_l1AdapterImplementation, _emptyInitTx)));
    emit L1AdapterDeployed(address(L1_ADAPTER_PROXY), _l1AdapterImplementation);

    // Deploy the upgrade manager implementation
    address _upgradeManagerImplementation = address(new UpgradeManager(address(L1_ADAPTER_PROXY)));
    // Deploy and initialize the upgrade manager proxy
    bytes memory _initializeTx = abi.encodeWithSelector(IUpgradeManager.initialize.selector, _owner);
    UpgradeManager(address(new ERC1967Proxy(address(_upgradeManagerImplementation), _initializeTx)));
    emit UpgradeManagerDeployed(address(UPGRADE_MANAGER), _upgradeManagerImplementation);
  }

  /**
   * @notice Sends the L2 factory creation tx along with the L2 deployments to be done on it through the messenger
   * @param _l1Messenger The address of the L1 messenger for the L2 Op chain
   * @param _usdcAdmin The address of the USDC admin
   * @param _minGasLimitCreate2Factory The minimum gas limit for the L2 factory deployment
   * @param _minGasLimitDeploy The minimum gas limit for calling the `deploy` function on the L2 factory
   */
  function deployL2FactoryAndContracts(
    address _l1Messenger,
    address _usdcAdmin,
    uint32 _minGasLimitCreate2Factory,
    uint32 _minGasLimitDeploy
  ) external {
    if (isMessengerDeployed[_l1Messenger]) revert IL1OpUSDCFactory_MessengerAlreadyDeployed();
    if (IUpgradeManager(UPGRADE_MANAGER).messengerDeploymentExecutor(_l1Messenger) != msg.sender) {
      revert IL1OpUSDCFactory_NotExecutor();
    }
    // Set the messenger as deployed and initialize it on the adapter
    isMessengerDeployed[_l1Messenger] = true;
    L1_ADAPTER_PROXY.initializeNewMessenger(_l1Messenger);

    // Get the L2 factory init code
    bytes memory _l2FactoryCreationCode = type(L2OpUSDCFactory).creationCode;
    bytes memory _l2FactoryCArgs = abi.encode(_SALT, address(this));
    bytes memory _l2FactoryInitCode = bytes.concat(_l2FactoryCreationCode, _l2FactoryCArgs);

    // Send the L2 factory deployment tx
    bytes memory _l2FactoryCreate2Tx =
      abi.encodeWithSelector(ICreate2Deployer.deploy.selector, _ZERO_VALUE, _SALT, _l2FactoryInitCode);
    ICrossDomainMessenger(_l1Messenger).sendMessage(
      L2_CREATE2_DEPLOYER, _l2FactoryCreate2Tx, _minGasLimitCreate2Factory
    );

    _deployL2USDCAndAdapter(_l1Messenger, _usdcAdmin, _minGasLimitDeploy);
  }

  /**
   * @notice Sends the L2 USDC and adapter deployments tx through the messenger to be executed on the l2 factory
   * @param _l1Messenger The address of the L1 messenger for the L2 Op chain
   * @param _usdcAdmin The address of the USDC admin
   * @param _minGasLimitDeploy The minimum gas limit for calling the `deploy` function on the L2 factory
   */
  function deployL2USDCAndAdapter(address _l1Messenger, address _usdcAdmin, uint32 _minGasLimitDeploy) external {
    if (IUpgradeManager(UPGRADE_MANAGER).messengerDeploymentExecutor(_l1Messenger) != msg.sender) {
      revert IL1OpUSDCFactory_NotExecutor();
    }
    _deployL2USDCAndAdapter(_l1Messenger, _usdcAdmin, _minGasLimitDeploy);
  }

  /**
   * @notice Deploys the L2 USDC implementation and adapter contracts
   * @param _l1Messenger The address of the L1 messenger for the L2 Op chain
   * @param _usdcAdmin The address of the USDC admin
   * @param _minGasLimitDeploy The minimum gas limit for calling the `deploy` function on the L2 factory
   */
  function _deployL2USDCAndAdapter(address _l1Messenger, address _usdcAdmin, uint32 _minGasLimitDeploy) internal {
    if (_usdcAdmin == L2_FACTORY) revert IL1OpUSDCFactory_InvalidUSDCAdmin();

    // Get the l2 usdc and adapter implementations
    IUpgradeManager.Implementation memory _l2Usdc = UPGRADE_MANAGER.bridgedUSDCImplementation();
    IUpgradeManager.Implementation memory _l2Adapter = UPGRADE_MANAGER.l2AdapterImplementation();

    // Send the call over the L2 factory `deploy` function message
    bytes memory _l2DeploymentsTx = abi.encodeWithSelector(
      L2OpUSDCFactory.deploy.selector,
      _l2Usdc.implementation.code,
      _l2Usdc.initTxs,
      _usdcAdmin,
      _l2Adapter.implementation.code,
      _l2Adapter.initTxs
    );
    ICrossDomainMessenger(_l1Messenger).sendMessage(L2_FACTORY, _l2DeploymentsTx, _minGasLimitDeploy);
  }

  /**
   * @notice Precalculates the address of a contract that will be deployed thorugh `CREATE` opcode
   * @dev It only works if the for nonces between 0 and 127, which is enough for this use case
   * @param _deployer The deployer address
   * @param _nonce The next nonce of the deployer address
   * @return _precalculatedAddress The address where the contract will be stored
   * @dev Only works for nonces between 1 and 127, which is enough for this use case
   */
  function _precalculateCreateAddress(
    address _deployer,
    uint256 _nonce
  ) internal pure returns (address _precalculatedAddress) {
    bytes memory _data;
    bytes1 _len = bytes1(0x94);
    // A one-byte integer in the [0x00, 0x7f] range uses its own value as a length prefix, there is no
    // additional "0x80 + length" prefix that precedes it.
    _data = abi.encodePacked(bytes1(0xd6), _len, _deployer, uint8(_nonce));
    _precalculatedAddress = address(uint160(uint256(keccak256(_data))));
  }

  /**
   * @notice Precalculate and address to be deployed using the `CREATE2` opcode
   * @param _salt The 32-byte random value used to create the contract address.
   * @param _initCodeHash The 32-byte bytecode digest of the contract creation bytecode.
   * @param _deployer The 20-byte _deployer address.
   * @return _computedAddress The 20-byte address where a contract will be stored.
   */
  function _precalculateCreate2Address(
    bytes32 _salt,
    bytes32 _initCodeHash,
    address _deployer
  ) internal pure returns (address _computedAddress) {
    assembly ("memory-safe") {
      let _ptr := mload(0x40)
      mstore(add(_ptr, 0x40), _initCodeHash)
      mstore(add(_ptr, 0x20), _salt)
      mstore(_ptr, _deployer)
      let _start := add(_ptr, 0x0b)
      mstore8(_start, 0xff)
      _computedAddress := keccak256(_start, 85)
    }
  }
}
