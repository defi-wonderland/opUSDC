// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface ICreate2Deployer {
  /**
   * @notice Deploys a contract using the CREATE2 opcode
   * @param _value The value to send with the deployment
   * @param _salt The salt value to use for the deployment
   * @param _code The init code to deploy
   */
  function deploy(uint256 _value, bytes32 _salt, bytes memory _code) external;
}
