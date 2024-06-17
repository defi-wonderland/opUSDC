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
   * @dev Changes the admin of the proxy.
   * Only the current admin can call this function.
   * @param newAdmin Address to transfer proxy administration to.
   */
  function changeAdmin(address newAdmin) external;

  /**
   * @dev Function to add/update a new minter
   * @param _minter The address of the minter
   * @param _minterAllowedAmount The minting amount allowed for the minter
   * @return _result True if the operation was successful.
   */
  function configureMinter(address _minter, uint256 _minterAllowedAmount) external returns (bool _result);

  /**
   * @notice Function to upgrade the usdc proxy to a new implementation
   * @param newImplementation Address of the new implementation
   */
  function upgradeTo(address newImplementation) external;

  /**
   * @notice Upgrades the USDC proxy to a new implementation and calls a function on the new implementation
   * @param newImplementation Address of the new implementation
   * @param data Data to call on the new implementation
   */
  function upgradeToAndCall(address newImplementation, bytes calldata data) external;

  /**
   * @notice Returns the current implementation address
   * @return _implementation Address of the current implementation
   */
  function implementation() external view returns (address _implementation);

  /**
   * @notice Returns the current master minter address
   * @return _masterMinter Address of the current master minter
   */
  function masterMinter() external view returns (address _masterMinter);
}
