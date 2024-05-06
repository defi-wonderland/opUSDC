// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IOpUSDCLockbox {
  /*///////////////////////////////////////////////////////////////
                            LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Burns locked USDC tokens
   * @dev The caller must be a minter and  must not be blacklisted
   */
  function burnLockedUSDC() external;
}
