// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {IOpUSDCLockbox} from 'interfaces/IOpUSDCLockbox.sol';
import {XERC20Lockbox} from 'xerc20/contracts/XERC20Lockbox.sol';

contract OpUSDCLockbox is IOpUSDCLockbox, Ownable, XERC20Lockbox {
  /**
   * @notice Construct the OpUSDCLockbox contract
   * @param _owner The address of the owner
   * @param _xerc20 The address of the XERC20 contract
   * @param _erc20 The address of the ERC20 contract
   */
  constructor(address _owner, address _xerc20, address _erc20) Ownable(_owner) XERC20Lockbox(_xerc20, _erc20, false) {}

  /// @inheritdoc IOpUSDCLockbox
  function burnLockedUSDC() external onlyOwner {
    (bool success,) = address(ERC20).call(abi.encodeWithSignature('burn(uint256)', ERC20.balanceOf(address(this))));
    if (!success) revert XERC20Lockbox_BurnFailed();
  }
}
