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
   * @param _newOwner Address to transfer ownership to
   */
  function transferOwnership(address _newOwner) external;

  /**
   * @notice Upgrades the USDC contract to a new implementation
   * @param _newImplementation Address of the new implementation
   */
  function upgradeTo(address _newImplementation) external;

  /**
   * @dev Changes the admin of the proxy.
   * Only the current admin can call this function.
   * @param newAdmin Address to transfer proxy administration to.
   */
  function changeAdmin(address newAdmin) external;

  /**
   * @notice Returns the current implementation address
   * @return _implementation Address of the current implementation
   */
  function implementation() external view returns (address _implementation);
}
