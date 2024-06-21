pragma solidity 0.8.25;

import {L2OpUSDCFactory} from 'contracts/L2OpUSDCFactory.sol';
import {ICreate2Deployer} from 'interfaces/external/ICreate2Deployer.sol';
import {ICrossDomainMessenger} from 'interfaces/external/ICrossDomainMessenger.sol';

library CrossChainDeployments {
  /**
   * @notice Deploys the L2 factory contract through the L1 messenger
   * @param _args The initialization arguments for the L2 factory
   * @param _salt The salt to be used to deploy the L2 factory
   * @param _messenger The address of the L1 messenger
   * @param _create2Deployer The address of the L2 create2 deployer
   * @param _minGasLimit The minimum gas limit that the message can be executed with
   * @return _l2Factory The address of the L2 factory
   */
  function deployL2Factory(
    bytes memory _args,
    bytes32 _salt,
    address _messenger,
    address _create2Deployer,
    uint32 _minGasLimit
  ) external returns (address _l2Factory) {
    bytes memory _l2FactoryInitCode = bytes.concat(type(L2OpUSDCFactory).creationCode, _args);
    _l2Factory = precalculateCreate2Address(_salt, keccak256(_l2FactoryInitCode), _create2Deployer);

    bytes memory _l2FactoryDeploymentsTx =
      abi.encodeWithSelector(ICreate2Deployer.deploy.selector, 0, _salt, _l2FactoryInitCode);
    ICrossDomainMessenger(_messenger).sendMessage(_create2Deployer, _l2FactoryDeploymentsTx, _minGasLimit);
  }

  /**
   * @notice Precalculate and address to be deployed using the `CREATE2` opcode
   * @param _salt The 32-byte random value used to create the contract address.
   * @param _initCodeHash The 32-byte bytecode digest of the contract creation bytecode.
   * @param _deployer The 20-byte _deployer address.
   * @return _precalculatedAddress The 20-byte address where a contract will be stored.
   */
  function precalculateCreate2Address(
    bytes32 _salt,
    bytes32 _initCodeHash,
    address _deployer
  ) public pure returns (address _precalculatedAddress) {
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

  /**
   * @notice Precalculates the address of a contract that will be deployed thorugh `CREATE` opcode
   * @param _deployer The deployer address
   * @param _nonce The next nonce of the deployer address
   * @return _precalculatedAddress The address where the contract will be stored
   * @dev Only works for nonces between 1 and (2 ** 64 - 2), which is enough for this use case
   */
  function precalculateCreateAddress(
    address _deployer,
    uint256 _nonce
  ) public pure returns (address _precalculatedAddress) {
    bytes memory _data;
    bytes1 _len = bytes1(0x94);

    // A one-byte integer in the [0x00, 0x7f] range uses its own value as a length prefix, there is no
    // additional "0x80 + length" prefix that precedes it.
    // A one-byte integer in the [0x00, 0x7f] range uses its own value as a length prefix, there is no
    // additional "0x80 + length" prefix that precedes it.
    if (_nonce <= 0x7f) {
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
}
