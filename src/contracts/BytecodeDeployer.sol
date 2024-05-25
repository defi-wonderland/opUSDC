// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

contract BytecodeDeployer {
  /**
   * @notice Deploys the contract with the given bytecode
   * @param _bytecode The bytecode to be assigned to the contract
   */
  constructor(bytes memory _bytecode) {
    assembly {
      let _dataStart := add(_bytecode, 0x20)
      let _dataSize := mload(_bytecode)
      return(_dataStart, _dataSize)
    }
  }
}
