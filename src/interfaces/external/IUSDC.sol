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
   * @notice allows a minter to burn some of its own tokens
   * Validates that caller is a minter and that sender is not blacklisted
   * amount is less than or equal to the minter's account balance
   * @param _amount uint256 the amount of tokens to be burned
   */
  function burn(uint256 _amount) external;

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
   * @param _newImplementation Address of the new implementation
   */
  function upgradeTo(address _newImplementation) external;

  /**
   * @notice Upgrades the USDC proxy to a new implementation and calls a function on the new implementation
   * @param _newImplementation Address of the new implementation
   * @param _data Data to call on the new implementation
   */
  function upgradeToAndCall(address _newImplementation, bytes calldata _data) external;

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

  /**
   * @notice Returns the current owner address
   * @return _owner Address of the current owner
   */
  function owner() external view returns (address _owner);
}
