// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {OpUSDCBridgeAdapter} from 'contracts/universal/OpUSDCBridgeAdapter.sol';
import {Test} from 'forge-std/Test.sol';
import {IOpUSDCBridgeAdapter} from 'interfaces/IOpUSDCBridgeAdapter.sol';

contract TestOpUSDCBridgeAdapter is OpUSDCBridgeAdapter {
  constructor(address _USDC, address _messenger) OpUSDCBridgeAdapter(_USDC, _messenger) {}

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

contract UnitStopMessaging is Base {
  event MessagingStopped();

  function testStopMessaging(address _linkedAdapter, uint32 _minGasLimit) public {
    vm.assume(_linkedAdapter != address(0));

    bytes memory _messageData = abi.encodeWithSignature('receiveStopMessaging()');

    vm.prank(_owner);
    adapter.setLinkedAdapter(_linkedAdapter);

    // Mock calls
    vm.mockCall(
      _messenger,
      abi.encodeWithSignature('sendMessage(address,bytes,uint32)', _linkedAdapter, _messageData, _minGasLimit),
      abi.encode('')
    );

    // Expect calls
    vm.expectCall(
      _messenger,
      abi.encodeWithSignature('sendMessage(address,bytes,uint32)', _linkedAdapter, _messageData, _minGasLimit)
    );

    // Execute
    vm.prank(_owner);
    adapter.stopMessaging(_minGasLimit);
    assertEq(adapter.isMessagingDisabled(), true, 'Messaging should be disabled');
  }

  function testReceiveStopMessaging(address _linkedAdapter) public {
    vm.assume(_linkedAdapter != address(0));

    vm.prank(_owner);
    adapter.setLinkedAdapter(_linkedAdapter);

    // Mock calls
    vm.mockCall(_messenger, abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_linkedAdapter));

    /// Expect calls
    vm.expectCall(_messenger, abi.encodeWithSignature('xDomainMessageSender()'));

    // Execute
    vm.prank(_messenger);
    adapter.receiveStopMessaging();
    assertEq(adapter.isMessagingDisabled(), true, 'Messaging should be disabled');
  }

  function testReceiveStopMessagingWrongMessenger(address _notMessenger) public {
    vm.assume(_notMessenger != _messenger);
    address _linkedAdapter = makeAddr('linkedAdapter');

    vm.prank(_owner);
    adapter.setLinkedAdapter(_linkedAdapter);

    // Execute
    vm.prank(_notMessenger);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidSender.selector);
    adapter.receiveStopMessaging();
    assertEq(adapter.isMessagingDisabled(), false, 'Messaging should not be disabled');
  }

  function testReceiveStopMessagingWrongLinkedAdapter() public {
    address _linkedAdapter = makeAddr('linkedAdapter');
    address _notLinkedAdapter = makeAddr('notLinkedAdapter');

    vm.prank(_owner);
    adapter.setLinkedAdapter(_linkedAdapter);

    // Mock calls
    vm.mockCall(_messenger, abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_notLinkedAdapter));

    /// Expect calls
    vm.expectCall(_messenger, abi.encodeWithSignature('xDomainMessageSender()'));

    // Execute
    vm.prank(_messenger);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidSender.selector);
    adapter.receiveStopMessaging();
    assertEq(adapter.isMessagingDisabled(), false, 'Messaging should not be disabled');
  }

  function testStopMessagingEmitsEvent(address _linkedAdapter, uint32 _minGasLimit) public {
    vm.assume(_linkedAdapter != address(0));

    bytes memory _messageData = abi.encodeWithSignature('receiveStopMessaging()');

    vm.prank(_owner);
    adapter.setLinkedAdapter(_linkedAdapter);

    /// Mock calls
    vm.mockCall(
      _messenger,
      abi.encodeWithSignature('sendMessage(address,bytes,uint32)', _linkedAdapter, _messageData, _minGasLimit),
      abi.encode('')
    );

    // Expect events
    vm.expectEmit(true, true, true, true);
    emit MessagingStopped();

    // Execute
    vm.prank(_owner);
    adapter.stopMessaging(_minGasLimit);
  }

  function testReceiveStopMessagingEmitsEvent(address _linkedAdapter) public {
    vm.assume(_linkedAdapter != address(0));

    vm.prank(_owner);
    adapter.setLinkedAdapter(_linkedAdapter);

    // Mock calls
    vm.mockCall(_messenger, abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_linkedAdapter));

    // Expect events
    vm.expectEmit(true, true, true, true);
    emit MessagingStopped();

    // Execute
    vm.prank(_messenger);
    adapter.receiveStopMessaging();
  }
}
