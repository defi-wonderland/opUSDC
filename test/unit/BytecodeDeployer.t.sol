// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BytecodeDeployer} from 'contracts/BytecodeDeployer.sol';
import {Test} from 'forge-std/Test.sol';

contract BytecodeDeployer_Unit_Deployment is Test {
  /**
   * @notice Check the bytecode deployer contract can be deployed with the given bytecode
   * @dev '0x6080' is applied to the input bytecode to avoid the `CreateContractStartingWithEF()` EVM error
   */
  function test_deployBytecode(bytes memory _inputBytecode) public {
    // Deploy the contract with the given bytecode
    bytes memory _bytecode = bytes.concat('0x6080', _inputBytecode);
    address deployed = address(new BytecodeDeployer(_bytecode));
    assertEq(deployed.code, _bytecode);
  }
}
