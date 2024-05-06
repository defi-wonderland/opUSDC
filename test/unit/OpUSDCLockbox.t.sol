// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test} from 'forge-std/Test.sol';

abstract contract Base is Test {
  // TODO: Setup

  function setUp() public virtual {}
}

// TODO: Delete this, it needs to be here for workflow to pass for now
contract UnitTest is Base {
  function testTest() public {
    uint256 _num = 1;
    assertEq(_num, _num);
  }
}

contract IntegrationTest is Base {
  function testTest() public {
    uint256 _num = 1;
    assertEq(_num, _num);
  }
}
