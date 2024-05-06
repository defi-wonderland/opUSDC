// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test} from 'forge-std/Test.sol';
import {OpUSDCBridgeAdapter} from 'contracts/OpUSDCBridgeAdapter.sol';

abstract contract Base is Test {
  OpUSDCBridgeAdapter public adapter;

  address internal _owner = makeAddr('owner');
  address internal _bridgedUSDC = makeAddr('opUSDC');
  address internal _messenger = makeAddr('messenger');
  address internal _lockbox = makeAddr('lockbox');

  event LinkedAdapterSet(address linkedAdapter);

  function setUp() public virtual {
    vm.prank(_owner);
    adapter = new OpUSDCBridgeAdapter(_bridgedUSDC, _lockbox, _messenger);
  }
}

contract UnitInitialization is Base {
  function testInitialization() public {
    assertEq(adapter.BRIDGED_USDC(), _bridgedUSDC);
    assertEq(adapter.LOCKBOX(), _lockbox);
    assertEq(adapter.MESSENGER(), _messenger);
  }

  function testLinkedAdapter() public {
    address _linkedAdapter = makeAddr('linkedAdapter');
    vm.prank(_owner);
    adapter.setLinkedAdapter(_linkedAdapter);
    assertEq(adapter.linkedAdapter(), _linkedAdapter, 'Linked adapter should be set to the new adapter');
  }

  function testZeroAddressLockbox() public {
    vm.prank(_owner);
    OpUSDCBridgeAdapter _adapter = new OpUSDCBridgeAdapter(_bridgedUSDC, address(0), _messenger);
    assertEq(_adapter.LOCKBOX(), address(0), 'Lockbox should be set to address(0)');
  }

  function testSetLinkedAdapterEmitsEvent() public {
    address _linkedAdapter = makeAddr('linkedAdapter');
    vm.prank(_owner);
    vm.expectEmit(true, true, true, true);
    emit LinkedAdapterSet(_linkedAdapter);
    adapter.setLinkedAdapter(_linkedAdapter);
  }
}
