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
   * @notice Initializes the fiat token contract.
   * @param _tokenName       The name of the fiat token.
   * @param _tokenSymbol     The symbol of the fiat token.
   * @param _tokenCurrency   The fiat currency that the token represents.
   * @param _tokenDecimals   The number of decimals that the token uses.
   * @param _newMasterMinter The masterMinter address for the fiat token.
   * @param _newPauser       The pauser address for the fiat token.
   * @param _newBlacklister  The blacklister address for the fiat token.
   * @param _newOwner        The owner of the fiat token.
   */
  function initialize(
    string memory _tokenName,
    string memory _tokenSymbol,
    string memory _tokenCurrency,
    uint8 _tokenDecimals,
    address _newMasterMinter,
    address _newPauser,
    address _newBlacklister,
    address _newOwner
  ) external;

  /**
   * @notice Updates the master minter address.
   * @param _newMasterMinter The address of the new master minter.
   */
  function updateMasterMinter(address _newMasterMinter) external;

  /**
   * @notice Adds or updates a new minter with a mint allowance.
   * @param _minter The address of the minter.
   * @param _minterAllowedAmount The minting amount allowed for the minter.
   * @return _success True if the minter was added or updated successfully.
   */
  function configureMinter(address _minter, uint256 _minterAllowedAmount) external returns (bool _success);

  /**
   * @return _name The name of the token
   */
  function name() external view returns (string memory _name);

  /**
   * @return _symbol The symbol of the token
   */
  function symbol() external view returns (string memory _symbol);

  /**
   * @return _currency The currency of the token
   */
  function currency() external view returns (string memory _currency);

  /**
   * @return _decimals The decimals of the token
   */
  function decimals() external view returns (uint8 _decimals);

  /**
   * @notice Returns the current implementation address
   * @return _implementation Address of the current implementation
   */
  function implementation() external view returns (address _implementation);
}
