// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {MessageHashUtils} from '@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol';
import {Test} from 'forge-std/Test.sol';

contract Helpers is Test {
  using MessageHashUtils for bytes32;

  error Create2DeploymentFailed();

  /**
   * @notice Sets up a mock and expects a call to it
   *
   * @param _receiver The address to have a mock on
   * @param _calldata The calldata to mock and expect
   * @param _returned The data to return from the mocked call
   */
  function _mockAndExpect(address _receiver, bytes memory _calldata, bytes memory _returned) internal {
    vm.mockCall(_receiver, _calldata, _returned);
    vm.expectCall(_receiver, _calldata);
  }

  function _generateSignature(
    address _to,
    uint256 _amount,
    uint256 _deadline,
    uint256 _minGasLimit,
    uint256 _nonce,
    address _signerAd,
    uint256 _signerPk,
    address _adapter
  ) internal returns (bytes memory _signature) {
    vm.startPrank(_signerAd);
    bytes32 _digest = keccak256(abi.encode(_adapter, block.chainid, _to, _amount, _deadline, _minGasLimit, _nonce))
      .toEthSignedMessageHash();
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(_signerPk, _digest);
    _signature = abi.encodePacked(r, s, v);
    vm.stopPrank();
  }

  function _precalculateCreate2Address(
    bytes32 salt,
    bytes32 initCodeHash,
    address deployer
  ) internal pure returns (address computedAddress) {
    assembly ("memory-safe") {
      let ptr := mload(0x40)
      mstore(add(ptr, 0x40), initCodeHash)
      mstore(add(ptr, 0x20), salt)
      mstore(ptr, deployer)
      let start := add(ptr, 0x0b)
      mstore8(start, 0xff)
      computedAddress := keccak256(start, 85)
    }
  }

  function _precalculateCreateAddress(address _origin, uint256 _nonce) internal pure returns (address _address) {
    bytes memory _data;
    if (_nonce == 0x00) {
      _data = abi.encodePacked(bytes1(0xd6), bytes1(0x94), _origin, bytes1(0x80));
    } else if (_nonce <= 0x7f) {
      _data = abi.encodePacked(bytes1(0xd6), bytes1(0x94), _origin, uint8(_nonce));
    } else if (_nonce <= 0xff) {
      _data = abi.encodePacked(bytes1(0xd7), bytes1(0x94), _origin, bytes1(0x81), uint8(_nonce));
    } else if (_nonce <= 0xffff) {
      _data = abi.encodePacked(bytes1(0xd8), bytes1(0x94), _origin, bytes1(0x82), uint16(_nonce));
    } else if (_nonce <= 0xffffff) {
      _data = abi.encodePacked(bytes1(0xd9), bytes1(0x94), _origin, bytes1(0x83), uint24(_nonce));
    } else {
      _data = abi.encodePacked(bytes1(0xda), bytes1(0x94), _origin, bytes1(0x84), uint32(_nonce));
    }

    bytes32 _hash = keccak256(_data);
    assembly {
      mstore(0, _hash)
      _address := mload(0)
    }
  }
}
