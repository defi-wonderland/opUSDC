// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BytecodeDeployer} from 'contracts/BytecodeDeployer.sol';
import {Test} from 'forge-std/Test.sol';

contract BytecodeDeployer_Unit_Deployment is Test {
  /**
   * @notice Check the bytecode deployer contract can be deployed with the given bytecode
   * @dev '0x6080' is applied to the input bytecode to avoid the `CreateContractStartingWithEF()` EVM error
   * @dev Sometimes `msize()` can return more bytecode than expected as zeros, so we onnly need to compare the length
   * of the bytecode we are giving
   */
  function test_deployBytecode(bytes memory _inputBytecode) public {
    // Deploy the contract with the given bytecode
    bytes memory _bytecode = bytes.concat('0x6080', _inputBytecode);
    address _deployedContract = address(new BytecodeDeployer(_bytecode));
    bytes memory _deployedCode = extractBytes(_deployedContract.code, _bytecode.length);
    assertEq(_deployedCode, _bytecode);
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
}
