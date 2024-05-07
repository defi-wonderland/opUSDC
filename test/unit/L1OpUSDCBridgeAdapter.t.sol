pragma solidity ^0.8.25;

import {Test} from 'forge-std/Test.sol';
import {IOpUSDCBridgeAdapter} from 'interfaces/IOpUSDCBridgeAdapter.sol';
import {L1OpUSDCBridgeAdapter} from 'contracts/L1OpUSDCBridgeAdapter.sol';

abstract contract Base is Test {
  L1OpUSDCBridgeAdapter public adapter;

  address internal _owner = makeAddr('owner');
  address internal _user = makeAddr('user');
  address internal _usdc = makeAddr('opUSDC');
  address internal _messenger = makeAddr('messenger');

  event MessageSent(address _user, uint256 _amount, uint32 _minGasLimit);
  event MessageReceived(address _user, uint256 _amount);

  function setUp() public virtual {
    vm.prank(_owner);
    adapter = new L1OpUSDCBridgeAdapter(_usdc, _messenger);
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
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_NotLinkedAdapter.selector);
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
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_NotLinkedAdapter.selector);
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
