// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/**
 * @title BytecodeDeployer
 * @notice Wrapper to deploy a contract with the given bytecode
 */
contract BytecodeDeployer {
  /**
   * @notice Deploys the contract with the given bytecode
   * @param _bytecode The bytecode to be assigned to the contract
   */
  constructor(bytes memory _bytecode) {
    assembly {
      let _dataStart := add(_bytecode, 32)
      let _dataEnd := sub(msize(), _dataStart)
      return(_dataStart, _dataEnd)
    }
  }
}
