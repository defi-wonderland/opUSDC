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
   * @notice Initialize v2
   * @param _newName   New token name
   */
  // solhint-disable-next-line func-name-mixedcase
  function initializeV2(string calldata _newName) external;

  /**
   * @notice Initialize v2.1
   * @param _lostAndFound  The address to which the locked funds are sent
   */
  // solhint-disable-next-line func-name-mixedcase
  function initializeV2_1(address _lostAndFound) external;

  /**
   * @notice Initialize v2.2
   * @param _accountsToBlacklist   A list of accounts to migrate from the old blacklist
   * @param _newSymbol             New token symbol
   * data structure to the new blacklist data structure.
   */
  // solhint-disable-next-line func-name-mixedcase
  function initializeV2_2(address[] calldata _accountsToBlacklist, string calldata _newSymbol) external;

  /**
   * @dev Function to add/update a new minter
   * @param _minter The address of the minter
   * @param _minterAllowedAmount The minting amount allowed for the minter
   * @return _result True if the operation was successful.
   */
  function configureMinter(address _minter, uint256 _minterAllowedAmount) external returns (bool _result);

  /**
   * @notice Removes a minter.
   * @param _minter The address of the minter to remove.
   * @return _result True if the operation was successful.
   */
  function removeMinter(address _minter) external returns (bool _result);

  /**
   * @notice Updates the master minter address.
   * @param _newMasterMinter The address of the new master minter.
   */
  function updateMasterMinter(address _newMasterMinter) external;

  /**
   * @notice Adds account to blacklist
   * @param _account The address to blacklist
   */
  function blacklist(address _account) external;

  /**
   * @notice Removes account from blacklist.
   * @param _account The address to remove from the blacklist.
   */
  function unBlacklist(address _account) external;

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

  /**
   * @return _currency The currency of the token
   */
  function currency() external view returns (string memory _currency);

  /**
   * @return _decimals The decimals of the token
   */
  function decimals() external view returns (uint8 _decimals);

  /**
   * @return _name The name of the token
   */
  function name() external view returns (string memory _name);

  /**
   * @return _symbol The symbol of the token
   */
  function symbol() external view returns (string memory _symbol);

  /**
   * @notice Checks if an account is a minter.
   * @param _account The address to check.
   * @return _isMinter True if the account is a minter, false if the account is not a minter.
   */
  function isMinter(address _account) external view returns (bool _isMinter);

  /**
   * @notice Returns the allowance of a minter
   * @param _minter The address of the minter
   * @return _allowance The minting amount allowed for the minter
   */
  function minterAllowance(address _minter) external view returns (uint256 _allowance);

  /**
   * @notice Returns the address of the current pauser
   * @return _pauser Address of the current pauser
   */
  function pauser() external view returns (address _pauser);

  /**
   * @notice Returns the address of the current blacklister
   * @return _blacklister Address of the current blacklister
   */
  function blacklister() external view returns (address _blacklister);

  /**
   * @notice Checks if account is blacklisted
   * @param _account The address to check
   * @return _result True if the account is blacklisted, false if not
   */
  function isBlacklisted(address _account) external view returns (bool _result);

  /**
   * @notice Returns the address of the current admin
   * @return _admin Address of the current admin
   */
  function admin() external view returns (address _admin);
}
