// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IManager {
  /*///////////////////////////////////////////////////////////////
                            LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Transfers ownership of the contract this manages to circle
   */
  function transferOwnership() external;

  /*///////////////////////////////////////////////////////////////
                            VARIABLES
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Returns the address of circle
   */
  // solhint-disable-next-line func-name-mixedcase
  function CIRCLE() external view returns (address _circle);

  /**
   * @notice Returns the address of the contract the manager manages
   */
  // solhint-disable-next-line func-name-mixedcase
  function CONTROLLED_CONTRACT() external view returns (address _circle);
}
