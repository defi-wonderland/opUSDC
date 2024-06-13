// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {L1OpUSDCBridgeAdapter} from 'contracts/L1OpUSDCBridgeAdapter.sol';
import {L2OpUSDCFactory} from 'contracts/L2OpUSDCFactory.sol';
import {IL1OpUSDCFactory} from 'interfaces/IL1OpUSDCFactory.sol';
import {ICreate2Deployer} from 'interfaces/external/ICreate2Deployer.sol';
import {ICrossDomainMessenger} from 'interfaces/external/ICrossDomainMessenger.sol';

/**
 * @title L1OpUSDCFactory
 * @notice Factory contract to deploy and setup the `L1OpUSDCBridgeAdapter` contract on L1, and
 * precalculates the addresses of the L2 deployments to be done on the L2 factory.
 * @dev The salt is always different for each deployed instance of this contract on the L1 Factory, and the L2 contracts
 * are deployed with `CREATE` to guarantee that the addresses are unique among all the L2s, so we avoid a scenario where
 * L2 contracts have the same address on different L2s when triggered by different owners.
 */
contract L1OpUSDCFactory is IL1OpUSDCFactory {
  /// @inheritdoc IL1OpUSDCFactory
  address public constant L2_MESSENGER = 0x4200000000000000000000000000000000000007;

  /// @inheritdoc IL1OpUSDCFactory
  address public constant L2_CREATE2_DEPLOYER = 0x13b0D85CcB8bf860b6b79AF3029fCA081AE9beF2;

  /// @notice Zero value constant to be used on the `CREATE2_DEPLOYER` interaction
  uint256 internal constant _ZERO_VALUE = 0;

  /// @inheritdoc IL1OpUSDCFactory
  address public immutable USDC;

  /// @inheritdoc IL1OpUSDCFactory
  mapping(address _l2Factory => uint256 _l2FactoryNonce) public l2FactoryNonce;

  /// @inheritdoc IL1OpUSDCFactory
  mapping(bytes32 _salt => bool _isUsed) public isSaltUsed;

  /**
   * @notice Constructs the L1 factory contract
   * @param _usdc The address of the USDC contract
   */
  constructor(address _usdc) {
    USDC = _usdc;
  }

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
  ) external returns (address _l2Factory, address _l1Adapter, address _l2Adapter) {
    if (isSaltUsed[_l2FactorySalt]) revert IL1OpUSDCFactory_SaltAlreadyUsed();
    isSaltUsed[_l2FactorySalt] = true;

    // Get the L2 factory init code and precalculate the address
    bytes memory _l2FactoryCArgs = abi.encode(address(this));
    bytes memory _l2FactoryInitCode = bytes.concat(type(L2OpUSDCFactory).creationCode, _l2FactoryCArgs);

    // Precalculate the L2 factory address and store it in the struct
    _l2Factory = _precalculateCreate2Address(_l2FactorySalt, keccak256(_l2FactoryInitCode), L2_CREATE2_DEPLOYER);

    // Increment the nonce of the L2 factory to the value it will be after is deployed and update it in the struct
    uint256 _l2FactoryNonce = ++l2FactoryNonce[_l2Factory];

    // Send the L2 factory deployment tx
    bytes memory _l2FactoryCreate2Tx =
      abi.encodeWithSelector(ICreate2Deployer.deploy.selector, _ZERO_VALUE, _l2FactorySalt, _l2FactoryInitCode);
    ICrossDomainMessenger(_l1Messenger).sendMessage(
      L2_CREATE2_DEPLOYER, _l2FactoryCreate2Tx, _minGasLimitCreate2Factory
    );

    /// NOTE: Breaking CEI pattern here, but it is safe to trust in the messenger
    (_l1Adapter, _l2Adapter) =
      _deployAdapters(_l1Messenger, _l1AdapterOwner, _l2Factory, _l2FactoryNonce, _l2Deployments);
  }

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
  ) public returns (address _l1Adapter, address _l2Adapter) {
    if (l2FactoryNonce[_l2Factory] == 0) revert IL1OpUSDCFactory_L2FactoryNotDeployed();
    uint256 _l2FactoryNonce = l2FactoryNonce[_l2Factory];
    (_l1Adapter, _l2Adapter) =
      _deployAdapters(_l1Messenger, _l1AdapterOwner, _l2Factory, _l2FactoryNonce, _l2Deployments);
  }

  /**
   * @notice Sends the L2 adapter and USDC proxy and implementation deployments tx through the messenger
   * to be executed on the l2 factory
   * @param _l1Messenger The address of the L1 messenger for the L2 Op chain
   * @param _l1AdapterOwner The address of the owner of the L1 adapter
   * @param _l2Deployments The deployments data for the L2 adapter, and the L2 USDC contracts
   * @return _l1Adapter The address of the L1 adapter
   * @return _l2Adapter The address of the L2 adapter
   */
  function _deployAdapters(
    address _l1Messenger,
    address _l1AdapterOwner,
    address _l2Factory,
    uint256 _l2FactoryNonce,
    L2Deployments memory _l2Deployments
  ) internal returns (address _l1Adapter, address _l2Adapter) {
    // Calculate the L2 adapter address. Adding 2 since the USDC contracts are already deployed first on the L2 factory
    uint256 _l2AdapterDeploymentNonce = _l2FactoryNonce + 2;
    _l2Adapter = _precalculateCreateAddress(_l2Factory, _l2AdapterDeploymentNonce);

    // Deploy the L1 adapter
    _l1Adapter = address(new L1OpUSDCBridgeAdapter(USDC, _l1Messenger, _l2Adapter, _l1AdapterOwner));

    // Increment the nonce of the L2 factory with all the deployments to be done
    l2FactoryNonce[_l2Factory] = _l2FactoryNonce + 3;

    // Send the call over the L2 factory `deploy` function message
    bytes memory _l2DeploymentsTx = abi.encodeWithSelector(
      L2OpUSDCFactory.deploy.selector,
      _l1Adapter,
      _l2Deployments.l2AdapterOwner,
      _l2Deployments.usdcImplementationInitCode,
      _l2Deployments.usdcInitTxs
    );
    ICrossDomainMessenger(_l1Messenger).sendMessage(_l2Factory, _l2DeploymentsTx, _l2Deployments.minGasLimitDeploy);

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
