// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {IOpUSDCLockbox} from 'interfaces/IOpUSDCLockbox.sol';
import {XERC20Lockbox} from 'xerc20/contracts/XERC20Lockbox.sol';
import {IXERC20} from 'xerc20/interfaces/IXERC20.sol';

contract OpUSDCLockbox is IOpUSDCLockbox, Ownable, XERC20Lockbox {
  /**
   * @notice Construct the OpUSDCLockbox contract
   * @param _owner The address of the owner
   * @param _xerc20 The address of the XERC20 contract
   * @param _erc20 The address of the ERC20 contract
   */
  constructor(address _owner, address _xerc20, address _erc20) Ownable(_owner) XERC20Lockbox(_xerc20, _erc20, false) {}

  /**
   * @notice Burns locked USDC tokens
   * @dev The caller must be a minter and  must not be blacklisted
   */
  function burnLockedUSDC() external onlyOwner {
    address _lockbox = address(this);
    IXERC20(address(ERC20)).burn(_lockbox, ERC20.balanceOf(_lockbox));
  }
}
