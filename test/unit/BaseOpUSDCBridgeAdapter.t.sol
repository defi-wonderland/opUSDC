// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BaseOpUSDCBridgeAdapter, IOpUSDCBridgeAdapter} from 'contracts/BaseOpUSDCBridgeAdapter.sol';
import {Test} from 'forge-std/Test.sol';

contract TestOpUSDCBridgeAdapter is BaseOpUSDCBridgeAdapter {
  constructor(address _USDC, address _messenger) BaseOpUSDCBridgeAdapter(_USDC, _messenger) {}

  function send(uint256 _amount, uint32 _minGasLimit) external override {}

  function receiveMessage(address _user, uint256 _amount) external override {}
}

abstract contract Base is Test {
  TestOpUSDCBridgeAdapter public adapter;

  address internal _owner = makeAddr('owner');
  address internal _usdc = makeAddr('opUSDC');
  address internal _messenger = makeAddr('messenger');

  event LinkedAdapterSet(address linkedAdapter);

  function setUp() public virtual {
    vm.prank(_owner);
    adapter = new TestOpUSDCBridgeAdapter(_usdc, _messenger);
  }
}

contract UnitInitialization is Base {
  function testInitialization() public {
    assertEq(adapter.USDC(), _usdc, 'USDC should be set to the provided address');
    assertEq(adapter.MESSENGER(), _messenger, 'Messenger should be set to the provided address');
    assertEq(adapter.linkedAdapter(), address(0), 'Linked adapter should be initialized to 0');
    assertEq(adapter.owner(), _owner, 'Owner should be set to the deployer');
  }

  function testLinkedAdapter() public {
    address _linkedAdapter = makeAddr('linkedAdapter');

    vm.prank(_owner);
    adapter.setLinkedAdapter(_linkedAdapter);
    assertEq(adapter.linkedAdapter(), _linkedAdapter, 'Linked adapter should be set to the new adapter');
  }

  function testSetLinkedAdapterEmitsEvent() public {
    address _linkedAdapter = makeAddr('linkedAdapter');

    vm.prank(_owner);
    vm.expectEmit(true, true, true, true);
    emit LinkedAdapterSet(_linkedAdapter);
    adapter.setLinkedAdapter(_linkedAdapter);
  }
}
