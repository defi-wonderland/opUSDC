pragma solidity ^0.8.25;

import {L2OpUSDCBridgeAdapter} from 'contracts/L2OpUSDCBridgeAdapter.sol';
import {IOpUSDCBridgeAdapter} from 'interfaces/IOpUSDCBridgeAdapter.sol';
import {Helpers} from 'test/utils/Helpers.sol';

contract ForTestL2OpUSDCBridgeAdapter is L2OpUSDCBridgeAdapter {
  constructor(
    address _usdc,
    address _messenger,
    address _linkedAdapter
  ) L2OpUSDCBridgeAdapter(_usdc, _messenger, _linkedAdapter) {}

  function forTest_setIsMessagingDisabled() external {
    isMessagingDisabled = true;
  }
}

abstract contract Base is Helpers {
  ForTestL2OpUSDCBridgeAdapter public adapter;

  address internal _user = makeAddr('user');
  address internal _usdc = makeAddr('opUSDC');
  address internal _messenger = makeAddr('messenger');
  address internal _linkedAdapter = makeAddr('linkedAdapter');

  event MessageSent(address _user, address _to, uint256 _amount, uint32 _minGasLimit);
  event MessageReceived(address _user, uint256 _amount);

  function setUp() public virtual {
    adapter = new ForTestL2OpUSDCBridgeAdapter(_usdc, _messenger, _linkedAdapter);
  }
}

contract L2OpUSDCBridgeAdapter_Unit_Constructor is Base {
  /**
   * @notice Check that the constructor works as expected
   */
  function test_constructorParams() public {
    assertEq(adapter.USDC(), _usdc, 'USDC should be set to the provided address');
    assertEq(adapter.MESSENGER(), _messenger, 'Messenger should be set to the provided address');
    assertEq(adapter.LINKED_ADAPTER(), _linkedAdapter, 'Linked adapter should be set to the provided address');
  }
}

contract L2OpUSDCBridgeAdapter_Unit_SendMessage is Base {
  /**
   * @notice Check that sending a message reverts if messaging is disabled
   */
  function test_revertOnMessagingDisabled(address _to, uint256 _amount, uint32 _minGasLimit) external {
    adapter.forTest_setIsMessagingDisabled();

    // Execute
    vm.prank(_user);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_MessagingDisabled.selector);
    adapter.sendMessage(_to, _amount, _minGasLimit);
  }

  /**
   * @notice Check that burning tokens and sending a message works as expected
   */
  function test_expectedCall(address _to, uint256 _amount, uint32 _minGasLimit) external {
    _mockAndExpect(address(_usdc), abi.encodeWithSignature('burn(address,uint256)', _user, _amount), abi.encode(true));
    _mockAndExpect(
      address(_messenger),
      abi.encodeWithSignature(
        'sendMessage(address,bytes,uint32)',
        _linkedAdapter,
        abi.encodeWithSignature('receiveMessage(address,uint256)', _to, _amount),
        _minGasLimit
      ),
      abi.encode()
    );

    // Execute
    vm.prank(_user);
    adapter.sendMessage(_to, _amount, _minGasLimit);
  }

  /**
   * @notice Check that the event is emitted as expected
   */
  function test_emitEvent(address _to, uint256 _amount, uint32 _minGasLimit) external {
    // Mock calls
    vm.mockCall(address(_usdc), abi.encodeWithSignature('burn(address,uint256)', _user, _amount), abi.encode(true));

    vm.mockCall(
      address(_messenger),
      abi.encodeWithSignature(
        'sendMessage(address,bytes,uint32)',
        _linkedAdapter,
        abi.encodeWithSignature('receiveMessage(address,uint256)', _to, _amount),
        _minGasLimit
      ),
      abi.encode()
    );

    // Expect events
    vm.expectEmit(true, true, true, true);
    emit MessageSent(_user, _to, _amount, _minGasLimit);

    // Execute
    vm.prank(_user);
    adapter.sendMessage(_to, _amount, _minGasLimit);
  }
}

contract L2OpUSDCBridgeAdapter_Unit_ReceiveMessage is Base {
  /**
   * @notice Check that the function reverts if the sender is not the messenger
   */
  function test_revertIfNotMessenger(uint256 _amount) external {
    // Execute
    vm.prank(_user);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidSender.selector);
    adapter.receiveMessage(_user, _amount);
  }

  /**
   * @notice Check that the function reverts if the linked adapter didn't send the message
   */
  function test_revertIfLinkedAdapterDidntSendTheMessage(uint256 _amount, address _messageSender) external {
    vm.assume(_linkedAdapter != _messageSender);

    // Mock calls
    vm.mockCall(address(_messenger), abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_messageSender));

    // Execute
    vm.prank(_messenger);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidSender.selector);
    adapter.receiveMessage(_user, _amount);
  }

  /**
   * @notice Check that the token minting works as expected
   */
  function test_sendTokens(uint256 _amount) external {
    // Mock calls
    vm.mockCall(address(_messenger), abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_linkedAdapter));

    _mockAndExpect(address(_usdc), abi.encodeWithSignature('mint(address,uint256)', _user, _amount), abi.encode(true));

    // Execute
    vm.prank(_messenger);
    adapter.receiveMessage(_user, _amount);
  }

  /**
   * @notice Check that the event is emitted as expected
   */
  function test_emitEvent(uint256 _amount) external {
    // Mock calls
    vm.mockCall(address(_messenger), abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_linkedAdapter));

    vm.mockCall(address(_usdc), abi.encodeWithSignature('mint(address,uint256)', _user, _amount), abi.encode(true));

    // Execute
    vm.expectEmit(true, true, true, true);
    emit MessageReceived(_user, _amount);

    vm.prank(_messenger);
    adapter.receiveMessage(_user, _amount);
  }
}

contract L2OpUSDCBridgeAdapter_Unit_ReceiveStopMessaging is Base {
  event MessagingStopped();

  /**
   * @notice Check that the function reverts if the sender is not the messenger
   */
  function test_wrongMessenger(address _notMessenger) public {
    vm.assume(_notMessenger != _messenger);

    // Execute
    vm.prank(_notMessenger);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidSender.selector);
    adapter.receiveStopMessaging();
    assertEq(adapter.isMessagingDisabled(), false, 'Messaging should not be disabled');
  }

  /**
   * @notice Check that the function reverts if the linked adapter didn't send the message
   */
  function test_wrongLinkedAdapter() public {
    address _notLinkedAdapter = makeAddr('notLinkedAdapter');

    _mockAndExpect(_messenger, abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_notLinkedAdapter));

    // Execute
    vm.prank(_messenger);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidSender.selector);
    adapter.receiveStopMessaging();
    assertEq(adapter.isMessagingDisabled(), false, 'Messaging should not be disabled');
  }

  /**
   * @notice Check that isMessagingDisabled is set to true
   */
  function test_setIsMessagingDisabledToTrue() public {
    _mockAndExpect(_messenger, abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_linkedAdapter));

    // Execute
    vm.prank(_messenger);
    adapter.receiveStopMessaging();
    assertEq(adapter.isMessagingDisabled(), true, 'Messaging should be disabled');
  }

  /**
   * @notice Check that the event is emitted as expected
   */
  function test_emitEvent() public {
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
