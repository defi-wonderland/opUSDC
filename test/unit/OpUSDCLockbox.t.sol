// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IOpUSDCLockbox, OpUSDCLockbox} from 'contracts/OpUSDCLockbox.sol';
import {Test} from 'forge-std/Test.sol';

abstract contract Base is Test {
  OpUSDCLockbox internal _lockbox;

  address internal _owner = makeAddr('owner');
  address internal _xerc20 = makeAddr('xerc20');
  address internal _erc20 = makeAddr('erc20');

  function setUp() public virtual {
    _lockbox = new OpUSDCLockbox(_owner, _xerc20, _erc20);
    vm.etch(address(_erc20), new bytes(0x1));
  }
}

contract UnitInitialization is Base {
  function testInitialization() public {
    assertEq(_lockbox.owner(), _owner);
    assertEq(address(_lockbox.XERC20()), _xerc20);
    assertEq(address(_lockbox.ERC20()), _erc20);
  }
}

contract UnitBurnLockedUSDC is Base {
  function testBurnLockedUSDC(uint256 _balance) public {
    vm.mockCall(_erc20, abi.encodeWithSignature('balanceOf(address)', _lockbox), abi.encode(_balance));
    vm.mockCall(_erc20, abi.encodeWithSignature('burn(uint256)', _balance), abi.encode(true, bytes('')));
    vm.prank(_owner);
    _lockbox.burnLockedUSDC();
  }

  function testBurnLockedUSDCRevert(uint256 _balance) public {
    vm.mockCall(_erc20, abi.encodeWithSignature('balanceOf(address)', _lockbox), abi.encode(_balance));
    vm.mockCall(_erc20, abi.encodeWithSignature('burn(uint256)', _balance), abi.encode(false, bytes('')));
    vm.prank(_owner);
    vm.expectRevert(IOpUSDCLockbox.XERC20Lockbox_BurnFailed.selector);
    _lockbox.burnLockedUSDC();
  }
}
