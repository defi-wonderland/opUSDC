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

  uint256 internal constant _ONE_DEPLOYMENT = 1;

  /// @notice Zero value constant to be used on portal interaction
  uint256 internal constant _ZERO_VALUE = 0;

  /// @inheritdoc IL1OpUSDCFactory
  address public immutable USDC;

  /// @inheritdoc IL1OpUSDCFactory
  address public immutable L2_FACTORY;

  /// @notice Salt value to be used to deploy the L2 contracts on the L2 factory
  bytes32 internal immutable _SALT;

  /// @inheritdoc IL1OpUSDCFactory
  uint256 public l2FactoryNonce = 1;

  /// @inheritdoc IL1OpUSDCFactory
  mapping(address _l1Messenger => bool _isDeployed) public isFactoryDeployed;

  /**
   * @notice Constructs the L1 factory contract
   * @param _usdc The address of the USDC contract
   * @param _salt The salt value to be used to deploy the L2 contracts with `CREATE2` on the L2 factory
   */
  constructor(address _usdc, bytes32 _salt) {
    USDC = _usdc;
    _SALT = _salt;

    bytes memory _l2FactoryCArgs = abi.encode(_SALT, address(this));
    bytes memory _l2FactoryInitCode = bytes.concat(type(L2OpUSDCFactory).creationCode, _l2FactoryCArgs);
    L2_FACTORY = _precalculateCreate2Address(_SALT, keccak256(_l2FactoryInitCode), L2_CREATE2_DEPLOYER);
  }

  /**
   * @notice Sends the L2 factory creation tx along with the L2 deployments to be done on it through the messenger in
   * addition to the L1 adapter deployment
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

    /// NOTE: Breaking CEI while invoking this call, but it's safe to trust in the Messenger
    _deployAdapters(_l1Messenger, _l1AdapterOwner, _minGasLimitDeploy, _usdcInitTxs);
  }

  /**
   * @notice Sends the L2 adapter and USDC proxy and implementation deployments tx through the messenger
   * to be executed on the l2 factory
   * @param _l1Messenger The address of the L1 messenger for the L2 Op chain
   * @param _l1AdapterOwner The address of the owner of the L1 adapter
   * @param _minGasLimitDeploy The minimum gas limit for calling the `deploy` function on the L2 factory
   * @param _usdcInitTxs The initialization transactions to be executed on the USDC contract
   */
  function deployAdapters(
    address _l1Messenger,
    address _l1AdapterOwner,
    uint32 _minGasLimitDeploy,
    bytes[] memory _usdcInitTxs
  ) public {
    if (!isFactoryDeployed[_l1Messenger]) revert IL1OpUSDCFactory_FactoryNotDeployed();
    _deployAdapters(_l1Messenger, _l1AdapterOwner, _minGasLimitDeploy, _usdcInitTxs);
  }

  function _deployAdapters(
    address _l1Messenger,
    address _l1AdapterOwner,
    uint32 _minGasLimitDeploy,
    bytes[] memory _usdcInitTxs
  ) internal {
    // Calculate the L2 adapter address. Substracting 2 from the nonce since is the 2nd deployment from the 3 to be done
    uint256 _l2UsdcDeploymentNonce = l2FactoryNonce + 1;
    address _l2Adapter = _precalculateCreateAddress(L2_FACTORY, _l2UsdcDeploymentNonce);

    // Deploy the L1 adapter
    address _l1Adapter = address(new L1OpUSDCBridgeAdapter(USDC, _l1Messenger, _l2Adapter, _l1AdapterOwner));

    // Increment the L2 Factory nonce for the next L2 deployments
    l2FactoryNonce += 3;

    // Send the call over the L2 factory `deploy` function message
    bytes memory _usdcImplementationCode = IUSDC(USDC).implementation().code;
    bytes memory _l2DeploymentsTx =
      abi.encodeWithSelector(L2OpUSDCFactory.deploy.selector, _l1Adapter, _usdcImplementationCode, _usdcInitTxs);
    ICrossDomainMessenger(_l1Messenger).sendMessage(L2_FACTORY, _l2DeploymentsTx, _minGasLimitDeploy);

    emit L1AdapterDeployed(_l1Adapter);
  }

  /**
   * @notice Precalculates the address of a contract that will be deployed thorugh `CREATE` opcode
   * @param _deployer The deployer address
   * @param _nonce The next nonce of the deployer address
   * @return _precalculatedAddress The address where the contract will be stored
   * @dev Only works for nonces between 1 and 2**64-2, which is enough for this use case
   */
  function _precalculateCreateAddress(
    address _deployer,
    uint256 _nonce
  ) internal pure returns (address _precalculatedAddress) {
    bytes memory _data;
    bytes1 _len = bytes1(0x94);

    // The theoretical allowed limit, based on EIP-2681, for an account nonce is 2**64-2:
    // https://web.archive.org/web/20230921113252/https://eips.ethereum.org/EIPS/eip-2681.
    if (_nonce > type(uint64).max - 1) {
      revert IL1OpUSDCFactory_InvalidNonce();
    }
    // A one-byte integer in the [0x00, 0x7f] range uses its own value as a length prefix, there is no
    // additional "0x80 + length" prefix that precedes it.
    else if (_nonce <= 0x7f) {
      _data = abi.encodePacked(bytes1(0xd6), _len, _deployer, uint8(_nonce));
    }
    // In the case of `_nonce > 0x7f` and `_nonce <= type(uint8).max`, we have the following encoding scheme
    // (the same calculation can be carried over for higher _nonce bytes):
    // 0xda = 0xc0 (short RLP prefix) + 0x1a (= the bytes length of: 0x94 + address + 0x84 + _nonce, in hex),
    // 0x94 = 0x80 + 0x14 (= the bytes length of an address, 20 bytes, in hex),
    // 0x84 = 0x80 + 0x04 (= the bytes length of the _nonce, 4 bytes, in hex).
    else if (_nonce <= type(uint8).max) {
      _data = abi.encodePacked(bytes1(0xd7), _len, _deployer, bytes1(0x81), uint8(_nonce));
    } else if (_nonce <= type(uint16).max) {
      _data = abi.encodePacked(bytes1(0xd8), _len, _deployer, bytes1(0x82), uint16(_nonce));
    } else if (_nonce <= type(uint24).max) {
      _data = abi.encodePacked(bytes1(0xd9), _len, _deployer, bytes1(0x83), uint24(_nonce));
    } else if (_nonce <= type(uint32).max) {
      _data = abi.encodePacked(bytes1(0xda), _len, _deployer, bytes1(0x84), uint32(_nonce));
    } else if (_nonce <= type(uint40).max) {
      _data = abi.encodePacked(bytes1(0xdb), _len, _deployer, bytes1(0x85), uint40(_nonce));
    } else if (_nonce <= type(uint48).max) {
      _data = abi.encodePacked(bytes1(0xdc), _len, _deployer, bytes1(0x86), uint48(_nonce));
    } else if (_nonce <= type(uint56).max) {
      _data = abi.encodePacked(bytes1(0xdd), _len, _deployer, bytes1(0x87), uint56(_nonce));
    } else {
      _data = abi.encodePacked(bytes1(0xde), _len, _deployer, bytes1(0x88), uint64(_nonce));
    }

    _precalculatedAddress = address(uint160(uint256(keccak256(_data))));
  }

  /**
   * @notice Precalculate and address to be deployed using the `CREATE2` opcode
   * @param _salt The 32-byte random value used to create the contract address.
   * @param _initCodeHash The 32-byte bytecode digest of the contract creation bytecode.
   * @param _deployer The 20-byte _deployer address.
   * @return _precalculatedAddress The 20-byte address where a contract will be stored.
   */
  function _precalculateCreate2Address(
    bytes32 _salt,
    bytes32 _initCodeHash,
    address _deployer
  ) internal pure returns (address _precalculatedAddress) {
    assembly ("memory-safe") {
      let _ptr := mload(0x40)
      mstore(add(_ptr, 0x40), _initCodeHash)
      mstore(add(_ptr, 0x20), _salt)
      mstore(_ptr, _deployer)
      let _start := add(_ptr, 0x0b)
      mstore8(_start, 0xff)
      _precalculatedAddress := keccak256(_start, 85)
    }
  }
}
