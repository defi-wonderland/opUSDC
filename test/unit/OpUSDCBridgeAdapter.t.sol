// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {OpUSDCBridgeAdapter} from 'contracts/universal/OpUSDCBridgeAdapter.sol';
import {Test} from 'forge-std/Test.sol';
import {IOpUSDCBridgeAdapter} from 'interfaces/IOpUSDCBridgeAdapter.sol';

contract TestOpUSDCBridgeAdapter is OpUSDCBridgeAdapter {
  constructor(
    address _usdc,
    address _messenger,
    address _linkedAdapter
  ) OpUSDCBridgeAdapter(_usdc, _messenger, _linkedAdapter) {}

  function send(uint256 _amount, uint32 _minGasLimit) external override {}

  function receiveMessage(address _user, uint256 _amount) external override {}
}

abstract contract Base is Test {
  TestOpUSDCBridgeAdapter public adapter;

  address internal _owner = makeAddr('owner');
  address internal _usdc = makeAddr('opUSDC');
  address internal _messenger = makeAddr('messenger');
  address internal _linkedAdapter = makeAddr('linkedAdapter');

  function setUp() public virtual {
    vm.prank(_owner);
    adapter = new TestOpUSDCBridgeAdapter(_usdc, _messenger, _linkedAdapter);
  }
}

contract UnitInitialization is Base {
  function testInitialization() public {
    assertEq(adapter.USDC(), _usdc, 'USDC should be set to the provided address');
    assertEq(adapter.MESSENGER(), _messenger, 'Messenger should be set to the provided address');
    assertEq(adapter.LINKED_ADAPTER(), _linkedAdapter, 'Linked adapter should be initialized to 0');
    assertEq(adapter.owner(), _owner, 'Owner should be set to the deployer');
  }
}

contract UnitStopMessaging is Base {
  event MessagingStopped();

  function testStopMessaging(uint32 _minGasLimit) public {
    bytes memory _messageData = abi.encodeWithSignature('receiveStopMessaging()');

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

  function testReceiveStopMessaging() public {
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

    // Execute
    vm.prank(_notMessenger);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidSender.selector);
    adapter.receiveStopMessaging();
    assertEq(adapter.isMessagingDisabled(), false, 'Messaging should not be disabled');
  }

  function testReceiveStopMessagingWrongLinkedAdapter() public {
    address _notLinkedAdapter = makeAddr('notLinkedAdapter');

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

  function testStopMessagingEmitsEvent(uint32 _minGasLimit) public {
    bytes memory _messageData = abi.encodeWithSignature('receiveStopMessaging()');

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

  function testReceiveStopMessagingEmitsEvent() public {
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
