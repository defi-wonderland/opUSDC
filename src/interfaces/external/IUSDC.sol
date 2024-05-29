// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface IUSDC is IERC20 {
  /**
   * @notice Mints USDC tokens
   * @param _to Address to mint tokens to
   * @param _amount Amount of tokens to mint
   */
  function mint(address _to, uint256 _amount) external;

  /**
   * @notice Burns USDC tokens
   * @param _account Address to burn tokens from
   * @param _amount Amount of tokens to burn
   */
  function burn(address _account, uint256 _amount) external;

  /**
   * @notice Transfers USDC ownership  to another address
   * @param newOwner Address to transfer ownership to
   */
  function transferOwnership(address newOwner) external;
}
