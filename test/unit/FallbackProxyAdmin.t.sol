pragma solidity ^0.8.25;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';

import {FallbackProxyAdmin} from 'contracts/utils/FallbackProxyAdmin.sol';
import {Helpers} from 'test/utils/Helpers.sol';

abstract contract Base is Helpers {
  address internal _usdc = makeAddr('usdc');
  address internal _owner = makeAddr('owner');

  FallbackProxyAdmin public admin;

  function setUp() public virtual {
    vm.prank(_owner);
    admin = new FallbackProxyAdmin(_usdc);
  }
}

contract FallbackProxyAdmin_Unit_Constructor is Base {}

contract FallbackProxyAdmin_Unit_ChangeAdmin is Base {
  function test_revertIfNotOwner(address _newOwner) public {
    vm.assume(_newOwner != _owner);

    vm.prank(_newOwner);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _newOwner));
    admin.changeAdmin(_newOwner);
  }

  function test_changeAdmin(address _newOwner) public {
    vm.assume(_newOwner != _owner);

    _mockAndExpect(address(_usdc), abi.encodeWithSignature('changeAdmin(address)', _newOwner), abi.encode());
    vm.prank(_owner);
    admin.changeAdmin(_newOwner);
  }
}
