// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC1967Proxy} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import {L1OpUSDCBridgeAdapter} from 'contracts/L1OpUSDCBridgeAdapter.sol';
import {L2OpUSDCBridgeAdapter} from 'contracts/L2OpUSDCBridgeAdapter.sol';
import {L2OpUSDCFactory} from 'contracts/L2OpUSDCFactory.sol';
import {USDC_PROXY_CREATION_CODE} from 'contracts/utils/USDCProxyCreationCode.sol';
import {IL1OpUSDCFactory} from 'interfaces/IL1OpUSDCFactory.sol';
import {ICreate2Deployer} from 'interfaces/external/ICreate2Deployer.sol';
import {ICrossDomainMessenger} from 'interfaces/external/ICrossDomainMessenger.sol';
import {IUSDC} from 'interfaces/external/IUSDC.sol';

/**
 * @title L1OpUSDCFactory
 * @notice Factory contract to deploy and setup the `L1OpUSDCBridgeAdapter` and `UpgradeManager` contracts on L1, and
 * precalculates the addresses of the L2 deployments to be done on the L2 factory.
 */
contract L1OpUSDCFactory is IL1OpUSDCFactory {
  /// @inheritdoc IL1OpUSDCFactory
  address public constant L2_MESSENGER = 0x4200000000000000000000000000000000000007;

  /// @inheritdoc IL1OpUSDCFactory
  address public constant L2_CREATE2_DEPLOYER = 0x13b0D85CcB8bf860b6b79AF3029fCA081AE9beF2;

  /// @notice Zero value constant to be used on portal interaction
  uint256 internal constant _ZERO_VALUE = 0;

  /// @inheritdoc IL1OpUSDCFactory
  address public immutable USDC;

  /// @inheritdoc IL1OpUSDCFactory
  address public immutable L2_FACTORY;

  /// @notice Salt value to be used to deploy the L2 contracts on the L2 factory
  bytes32 internal immutable _SALT;

  /// @inheritdoc IL1OpUSDCFactory
  uint256 public nonce;

  /// @inheritdoc IL1OpUSDCFactory
  mapping(address _l1Messenger => bool _isDeployed) public isFactoryDeployed;

  /**
   * @notice Constructs the L1 factory contract, deploys the L1 adapter and the upgrade manager and precalculates the
   * addresses of the L2 deployments
   * @param _usdc The address of the USDC contract
   */
  constructor(address _usdc, bytes32 _salt) {
    // The WETH predeploy address on the OP Chains
    _SALT = _salt;
    USDC = _usdc;

    // Calculate L2 factory address
    bytes memory _l2FactoryCArgs = abi.encode(_SALT, address(this));
    bytes memory _l2FactoryInitCode = bytes.concat(type(L2OpUSDCFactory).creationCode, _l2FactoryCArgs);
    L2_FACTORY = _precalculateCreate2Address(_SALT, keccak256(_l2FactoryInitCode), L2_CREATE2_DEPLOYER);
  }

  /**
   * @notice Sends the L2 factory creation tx along with the L2 deployments to be done on it through the messenger
   * @param _l1Messenger The address of the L1 messenger for the L2 Op chain
   * @param _l1AdapterOwner The address of the owner of the L1 adapter
   * @param _minGasLimitCreate2Factory The minimum gas limit for the L2 factory deployment
   * @param _minGasLimitDeploy The minimum gas limit for calling the `deploy` function on the L2 factory
   * @param _usdcInitTxs The initialization transactions to be executed on the USDC contract
   */
  function deployL2FactoryAndContracts(
    address _l1Messenger,
    address _l1AdapterOwner,
    uint32 _minGasLimitCreate2Factory,
    uint32 _minGasLimitDeploy,
    bytes[] memory _usdcInitTxs
  ) external {
    // Set the messenger as deployed and initialize it on the adapter
    isFactoryDeployed[_l1Messenger] = true;

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

    deployAdapters(_l1Messenger, _l1AdapterOwner, _usdcInitTxs, _minGasLimitDeploy);
  }

  function deployAdapters(
    address _l1Messenger,
    address _l1AdapterOwner,
    bytes[] memory _usdcInitTxs,
    uint32 _minGasLimitDeploy
  ) public {
    if (!isFactoryDeployed[_l1Messenger]) revert IL1OpUSDCFactory_FactoryNotDeployed();
    _deployAdapters(_l1Messenger, _l1AdapterOwner, _usdcInitTxs, _minGasLimitDeploy);
  }

  function _deployAdapters(
    address _l1Messenger,
    address _l1AdapterOwner,
    bytes[] memory _usdcInitTxs,
    uint32 _minGasLimitDeploy
  ) internal {
    // Precalculate l1 adapter address
    uint256 _l1AdapterDeploymentNonce = nonce + 1;
    address _l1Adapter = _precalculateCreateAddress(address(this), _l1AdapterDeploymentNonce);

    // Precalculate l2 USDC proxy address
    bytes memory _l2UsdcProxyInitCode = bytes.concat(USDC_PROXY_CREATION_CODE, abi.encode(_l1Adapter));
    address _l2UsdcProxy = _precalculateCreate2Address(_SALT, keccak256(_l2UsdcProxyInitCode), L2_CREATE2_DEPLOYER);

    // Precalculate l2 adapter address
    bytes memory _l2AdapterInitCode =
      bytes.concat(type(L2OpUSDCBridgeAdapter).creationCode, abi.encode(_l2UsdcProxy, L2_MESSENGER, _l1Adapter));
    address _l2Adapter = _precalculateCreate2Address(_SALT, keccak256(_l2AdapterInitCode), L2_FACTORY);

    // Deploy the L1 adapter implementation
    new L1OpUSDCBridgeAdapter(USDC, _l1Messenger, _l2Adapter, _l1AdapterOwner);

    // Update the nonce with the following 2 txs
    nonce += 2;

    // Get the l2 USDC implementation
    bytes memory _usdcImplementationCode = IUSDC(USDC).implementation().code;
    // Send the call over the L2 factory `deploy` function message
    bytes memory _l2DeploymentsTx =
      abi.encodeWithSelector(L2OpUSDCFactory.deploy.selector, _l1Adapter, _usdcImplementationCode, _usdcInitTxs);
    ICrossDomainMessenger(_l1Messenger).sendMessage(L2_FACTORY, _l2DeploymentsTx, _minGasLimitDeploy);

    emit L1AdapterDeployed(_l1Adapter);
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
