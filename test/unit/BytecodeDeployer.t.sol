// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BytecodeDeployer} from 'contracts/utils/BytecodeDeployer.sol';
import {Test} from 'forge-std/Test.sol';

contract BytecodeDeployer_Unit_Deployment is Test {
  /**
   * @notice Check the bytecode deployer contract can be deployed with the given bytecode
   * @dev '0x6080' is applied to the input bytecode to avoid the `CreateContractStartingWithEF()` EVM error
   * @dev Sometimes `msize()` can return more bytecode than expected as zeros, so we only need to compare the length
   * of the bytecode we are giving, and then check that the rest of the bytecode is composed of zeros
   */
  function test_deployBytecode(bytes memory _inputBytecode) public {
    // Deploy the contract with the given bytecode
    bytes memory _bytecode = bytes.concat('0x6080', _inputBytecode);
    address _deployedContract = address(new BytecodeDeployer(_bytecode));
    // Get the deployed contract bytecode
    uint256 _start = 0;
    bytes memory _deployedCode = _extractBytes(_deployedContract.code, _start, _bytecode.length);
    bytes memory _extraBytes = _extractBytes(_deployedContract.code, _bytecode.length, _deployedContract.code.length);

    // Assert the deployed contract bytecode is the same as the input bytecode, and the rest of the bytecode is zeros
    assertEq(_deployedCode, _bytecode);
    assertEq(bytes32(_extraBytes), bytes32(0));
  }

  /**
   * @notice Extracts the first `length` bytes from the given bytecode
   * @param _bytecode The _bytecode to extract the bytes from
   * @param _length The number of bytes to extract
   * @return _result The extracted bytes
   */
  function extractBytes(bytes memory _bytecode, uint256 _length) public pure returns (bytes memory _result) {
    _result = new bytes(_length);
    for (uint256 i = 0; i < _length; i++) {
      _result[i] = _bytecode[i];
    }
    return _result;
  }

  function _extractBytes(
    bytes memory _bytecode,
    uint256 _start,
    uint256 _to
  ) internal pure returns (bytes memory _result) {
    uint256 _length = _to - _start;
    _result = new bytes(_length);
    for (uint256 i = 0; i < _length; i++) {
      _result[i] = _bytecode[i + _start];
    }
    return _result;
  }
}
