// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {Manager} from 'contracts/Manager.sol';
import {Helpers} from 'test/utils/Helpers.sol';

abstract contract Base is Helpers {
  Manager public manager;

  address internal _circle = makeAddr('circle');
  Ownable internal _controlledContract = Ownable(makeAddr('controlledContract'));
  address internal _owner = makeAddr('owner');

  function setUp() public virtual {
    vm.prank(_owner);
    manager = new Manager(_circle, _controlledContract);
  }
}

contract UnitInitialization is Base {
  function testInitialization() public {
    assertEq(manager.CIRCLE(), _circle, 'Circle should be set to the provided address');
    assertEq(manager.owner(), _owner, 'Owner should be set to the deployer');
    assertEq(
      address(manager.CONTROLLED_CONTRACT()),
      address(_controlledContract),
      'Controlled contract should be set to the provided address'
    );
  }
}

contract UnitOwnershipTransfer is Base {
  function testTransferOwnership() public {
    // Mock & Expect
    _mockAndExpect(
      address(_controlledContract), abi.encodeWithSignature('transferOwnership(address)', _circle), abi.encode()
    );

    vm.prank(_owner);
    // Execute
    manager.transferToCircle();
  }
}
