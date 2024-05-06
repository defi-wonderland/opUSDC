// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test} from 'forge-std/Test.sol';

contract IntegrationBase is Test {
  // TODO: Setup

  function setUp() public {}
}

// TODO: Delete this, it needs to be here for workflow to pass for now
contract IntegrationTest is IntegrationBase {
  function testTest() public {
    uint256 _num = 1;
    assertEq(_num, _num);
  }
}
