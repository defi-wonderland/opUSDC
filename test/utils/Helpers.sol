// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {MessageHashUtils} from '@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol';
import {Test} from 'forge-std/Test.sol';

contract Helpers is Test {
  using MessageHashUtils for bytes32;
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
    uint256 _nonce,
    address _signerAd,
    uint256 _signerPk,
    address _adapter
  ) internal returns (bytes memory _signature) {
    vm.startPrank(_signerAd);
    bytes32 digest = keccak256(abi.encodePacked(_adapter, block.chainid, _to, _amount, _nonce)).toEthSignedMessageHash();
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(_signerPk, digest);
    _signature = abi.encodePacked(r, s, v);
    vm.stopPrank();
  }
}
