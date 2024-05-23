// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

contract BytecodeDeployer {
  constructor(bytes memory _bytecode) {
    assembly {
      let _dataStart := add(_bytecode, 32)
      let _dataEnd := sub(msize(), _dataStart)
      return(_dataStart, _dataEnd)
    }
  }
}
