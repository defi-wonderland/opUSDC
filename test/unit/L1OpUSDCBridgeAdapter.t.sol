pragma solidity ^0.8.25;

import {L1OpUSDCBridgeAdapter} from 'contracts/L1OpUSDCBridgeAdapter.sol';
import {Test} from 'forge-std/Test.sol';
import {IOpUSDCBridgeAdapter} from 'interfaces/IOpUSDCBridgeAdapter.sol';

contract TestL1OpUSDCBridgeAdapter is L1OpUSDCBridgeAdapter {
  constructor(address _usdc, address _messenger) L1OpUSDCBridgeAdapter(_usdc, _messenger) {}

  function setIsMessagingDisabled() external {
    isMessagingDisabled = true;
  }
}

abstract contract Base is Test {
  TestL1OpUSDCBridgeAdapter public adapter;

  address internal _owner = makeAddr('owner');
  address internal _user = makeAddr('user');
  address internal _usdc = makeAddr('opUSDC');
  address internal _messenger = makeAddr('messenger');

  event MessageSent(address _user, uint256 _amount, uint32 _minGasLimit);
  event MessageReceived(address _user, uint256 _amount);
  event BurnAmountSet(uint256 _burnAmount);

  function setUp() public virtual {
    vm.prank(_owner);
    adapter = new TestL1OpUSDCBridgeAdapter(_usdc, _messenger);
  }
}

contract UnitMessaging is Base {
  function testSendMessage(uint256 _amount, uint32 _minGasLimit, address _linkedAdapter) external {
    vm.assume(_linkedAdapter != address(0));

    vm.prank(_owner);
    adapter.setLinkedAdapter(_linkedAdapter);

    // Mock calls
    vm.mockCall(
      address(_usdc),
      abi.encodeWithSignature('transferFrom(address,address,uint256)', _user, address(adapter), _amount),
      abi.encode(true)
    );

    vm.mockCall(
      address(_messenger),
      abi.encodeWithSignature(
        'sendMessage(address,bytes,uint32)',
        _linkedAdapter,
        abi.encodeWithSignature('receiveMessage(address,uint256)', _user, _amount),
        _minGasLimit
      ),
      abi.encode()
    );

    // Expect calls

    vm.expectCall(
      address(_usdc), abi.encodeWithSignature('transferFrom(address,address,uint256)', _user, address(adapter), _amount)
    );
    vm.expectCall(
      address(_messenger),
      abi.encodeWithSignature(
        'sendMessage(address,bytes,uint32)',
        _linkedAdapter,
        abi.encodeWithSignature('receiveMessage(address,uint256)', _user, _amount),
        _minGasLimit
      )
    );

    // Execute
    vm.prank(_user);
    adapter.send(_amount, _minGasLimit);
  }

  function testSendMessageRevertsOnMessagingStopped(
    uint256 _amount,
    uint32 _minGasLimit,
    address _linkedAdapter
  ) external {
    vm.assume(_linkedAdapter != address(0));

    vm.startPrank(_owner);
    adapter.setLinkedAdapter(_linkedAdapter);
    adapter.setIsMessagingDisabled();
    vm.stopPrank();

    // Execute
    vm.prank(_user);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_MessagingDisabled.selector);
    adapter.send(_amount, _minGasLimit);
  }

  function testSendMessageEmitsEvent(uint256 _amount, uint32 _minGasLimit, address _linkedAdapter) external {
    vm.assume(_linkedAdapter != address(0));

    vm.prank(_owner);
    adapter.setLinkedAdapter(_linkedAdapter);

    // Mock calls
    vm.mockCall(
      address(_usdc),
      abi.encodeWithSignature('transferFrom(address,address,uint256)', _user, address(adapter), _amount),
      abi.encode(true)
    );

    vm.mockCall(
      address(_messenger),
      abi.encodeWithSignature(
        'sendMessage(address,bytes,uint32)',
        _linkedAdapter,
        abi.encodeWithSignature('receiveMessage(address,uint256)', _user, _amount),
        _minGasLimit
      ),
      abi.encode()
    );

    // Expect events
    vm.expectEmit(true, true, true, true);
    emit MessageSent(_user, _amount, _minGasLimit);

    // Execute
    vm.prank(_user);
    adapter.send(_amount, _minGasLimit);
  }

  function testSendMessageRevertsIfAdapterNotSet(uint256 _amount, uint32 _minGasLimit) external {
    // Execute
    vm.prank(_user);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_LinkedAdapterNotSet.selector);
    adapter.send(_amount, _minGasLimit);
  }

  function testReceiveMessageRevertsIfNotMessenger(uint256 _amount, address _linkedAdapter) external {
    vm.assume(_linkedAdapter != address(0));

    vm.prank(_owner);
    adapter.setLinkedAdapter(_linkedAdapter);

    // Execute
    vm.prank(_user);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidSender.selector);
    adapter.receiveMessage(_user, _amount);
  }

  function testReceiveMessageRevertsIfLinkedAdapterDidntSendTheMessage(
    uint256 _amount,
    address _messageSender,
    address _linkedAdapter
  ) external {
    vm.assume(_linkedAdapter != address(0) && _linkedAdapter != _messageSender);

    vm.prank(_owner);
    adapter.setLinkedAdapter(_linkedAdapter);

    // Mock calls
    vm.mockCall(address(_messenger), abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_messageSender));

    // Execute
    vm.prank(_messenger);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidSender.selector);
    adapter.receiveMessage(_user, _amount);
  }

  function testReceiveMessageSendsTokens(uint256 _amount, address _linkedAdapter) external {
    vm.assume(_linkedAdapter != address(0));

    vm.prank(_owner);
    adapter.setLinkedAdapter(_linkedAdapter);

    // Mock calls
    vm.mockCall(address(_messenger), abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_linkedAdapter));

    vm.mockCall(address(_usdc), abi.encodeWithSignature('transfer(address,uint256)', _user, _amount), abi.encode(true));

    // Expect calls
    vm.expectCall(address(_usdc), abi.encodeWithSignature('transfer(address,uint256)', _user, _amount));

    // Execute
    vm.prank(_messenger);
    adapter.receiveMessage(_user, _amount);
  }

  function testReceiveMessageEmitsEvent(uint256 _amount, address _linkedAdapter) external {
    vm.assume(_linkedAdapter != address(0));

    vm.prank(_owner);
    adapter.setLinkedAdapter(_linkedAdapter);

    // Mock calls
    vm.mockCall(address(_messenger), abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_linkedAdapter));

    vm.mockCall(address(_usdc), abi.encodeWithSignature('transfer(address,uint256)', _user, _amount), abi.encode(true));

    // Execute
    vm.expectEmit(true, true, true, true);
    emit MessageReceived(_user, _amount);

    vm.prank(_messenger);
    adapter.receiveMessage(_user, _amount);
  }
}

contract UnitBurning is Base {
  function testBurnLockedUSDC(uint256 _burnAmount) external {
    // Mock calls
    vm.mockCall(
      address(_usdc), abi.encodeWithSignature('burn(address,uint256)', address(adapter), _burnAmount), abi.encode(true)
    );

    // Expect calls
    vm.expectCall(address(_usdc), abi.encodeWithSignature('burn(address,uint256)', address(adapter), _burnAmount));

    // Execute
    vm.startPrank(_owner);
    adapter.setBurnAmount(_burnAmount);
    adapter.burnLockedUSDC();
    vm.stopPrank();

    assertEq(adapter.burnAmount(), 0, 'Burn amount should be set to 0');
  }

  function testSetBurnLockedUSDC(uint256 _burnAmount) external {
    vm.assume(_burnAmount > 0);

    uint256 _originalBurnAmount = adapter.burnAmount();

    // Execute
    vm.prank(_owner);
    adapter.setBurnAmount(_burnAmount);

    // Assert
    assertEq(adapter.burnAmount(), _burnAmount, 'Burn amount should be set');
    assertGt(adapter.burnAmount(), _originalBurnAmount, 'Burn amount should be greater than the original amount');
  }

  function testSetBurnLockedUSDCEmitsEvent(uint256 _burnAmount) external {
    vm.assume(_burnAmount > 0);

    // Execute
    vm.prank(_owner);
    vm.expectEmit(true, true, true, true);
    emit BurnAmountSet(_burnAmount);
    adapter.setBurnAmount(_burnAmount);
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
}
