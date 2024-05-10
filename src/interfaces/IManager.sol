// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';

interface IManager {
  /*///////////////////////////////////////////////////////////////
                            LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Transfers ownership of the contract this manages to circle
   */
  function transferToCircle() external;

  /*///////////////////////////////////////////////////////////////
                            VARIABLES
  //////////////////////////////////////////////////////////////*/

  /**
   * @return _circle Returns the address of circle
   */
  // solhint-disable-next-line func-name-mixedcase
  function CIRCLE() external view returns (address _circle);

  /**
   * @return _controlledContract Returns the address of the contract the manager manages
   */
  // solhint-disable-next-line func-name-mixedcase
  function CONTROLLED_CONTRACT() external view returns (Ownable _controlledContract);
}
