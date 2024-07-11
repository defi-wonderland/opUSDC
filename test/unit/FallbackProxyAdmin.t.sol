// SPDX-License-Identifier: MIT
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
  /**
   * @notice Check that the contract reverts if the caller is not the owner
   */
  function test_revertIfNotOwner(address _newOwner) public {
    vm.assume(_newOwner != _owner);

    vm.prank(_newOwner);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _newOwner));
    admin.changeAdmin(_newOwner);
  }

  /**
   * @notice Check that the contract calls the `changeAdmin` function of the USDC contract
   */
  function test_changeAdmin(address _newOwner) public {
    vm.assume(_newOwner != _owner);

    _mockAndExpect(_usdc, abi.encodeWithSignature('changeAdmin(address)', _newOwner), abi.encode());
    vm.prank(_owner);
    admin.changeAdmin(_newOwner);
  }
}

contract FallbackProxyAdmin_Unit_UpgradeTo is Base {
  /**
   * @notice Check that the contract reverts if the caller is not the owner
   */
  function test_revertIfNotOwner(address _newImplementation) public {
    vm.assume(_newImplementation != _owner);

    vm.prank(_newImplementation);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _newImplementation));
    admin.upgradeTo(_newImplementation);
  }

  /**
   * @notice Check that the contract calls the `upgradeTo` function of the USDC contract
   */
  function test_upgradeTo(address _newImplementation) public {
    _mockAndExpect(_usdc, abi.encodeWithSignature('upgradeTo(address)', _newImplementation), abi.encode());
    vm.prank(_owner);
    admin.upgradeTo(_newImplementation);
  }
}

contract FallbackProxyAdmin_Unit_UpgradeToAndCall is Base {
  /**
   * @notice Check that the contract reverts if the caller is not the owner
   */
  function test_revertIfNotOwner(address _newImplementation, bytes memory _data) public {
    vm.assume(_newImplementation != _owner);

    vm.prank(_newImplementation);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _newImplementation));
    admin.upgradeToAndCall(_newImplementation, _data);
  }

  /**
   * @notice Check that the contract calls the `upgradeToAndCall` function of the USDC contract
   */
  function test_upgradeToAndCall(address _newImplementation, bytes memory _data) public {
    _mockAndExpect(
      _usdc, abi.encodeWithSignature('upgradeToAndCall(address,bytes)', _newImplementation, _data), abi.encode()
    );
    vm.prank(_owner);
    admin.upgradeToAndCall(_newImplementation, _data);
  }
}
