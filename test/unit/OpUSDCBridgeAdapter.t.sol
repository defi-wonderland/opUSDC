// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IOpUSDCBridgeAdapter, OpUSDCBridgeAdapter} from 'contracts/OpUSDCBridgeAdapter.sol';
import {Test} from 'forge-std/Test.sol';

abstract contract Base is Test {
  OpUSDCBridgeAdapter public adapter;

  address internal _owner = makeAddr('owner');
  address internal _user = makeAddr('user');
  address internal _bridgedUSDC = makeAddr('opUSDC');
  address internal _l1USDC = makeAddr('l1USDC');
  address internal _messenger = makeAddr('messenger');
  address internal _lockbox = makeAddr('lockbox');

  event LinkedAdapterSet(address _linkedAdapter);
  event MessageRecieved(address _user, uint256 _amount);
  event MessageSent(address _user, uint256 _amount, uint32 _minGasLimit);

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

  function testLinkedAdapter(address _linkedAdapter) public {
    vm.mockCall(address(_bridgedUSDC), abi.encodeWithSignature('owner()'), abi.encode(_owner));

    vm.prank(_owner);
    adapter.setLinkedAdapter(_linkedAdapter);
    assertEq(adapter.linkedAdapter(), _linkedAdapter, 'Linked adapter should be set to the new adapter');
  }

  function testZeroAddressLockbox() public {
    vm.prank(_owner);
    OpUSDCBridgeAdapter _adapter = new OpUSDCBridgeAdapter(_bridgedUSDC, address(0), _messenger);
    assertEq(_adapter.LOCKBOX(), address(0), 'Lockbox should be set to address(0)');
  }

  function testSetLinkedAdapterEmitsEvent(address _linkedAdapter) public {
    vm.mockCall(address(_bridgedUSDC), abi.encodeWithSignature('owner()'), abi.encode(_owner));

    vm.prank(_owner);
    vm.expectEmit(true, true, true, true);
    emit LinkedAdapterSet(_linkedAdapter);
    adapter.setLinkedAdapter(_linkedAdapter);
  }

  function testRevertsIfOwnerDoesntMatch(address _linkedAdapter) public {
    vm.mockCall(address(_bridgedUSDC), abi.encodeWithSignature('owner()'), abi.encode(makeAddr('notOwner')));

    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_NotTokenIssuer.selector);
    vm.prank(_owner);
    adapter.setLinkedAdapter(_linkedAdapter);
  }
}

contract UnitMessaging is Base {
  function testSendRevertsWithUnsetAdapter(bool _isCanonical, uint256 _amount, uint32 _minGasLimit) public {
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_LinkedAdapterNotSet.selector);
    adapter.send(_isCanonical, _amount, _minGasLimit);
  }

  function testBridgedTokenIsBurnedAndMessageSent(uint256 _amount, uint32 _minGasLimit, address _linkedAdapter) public {
    vm.assume(_linkedAdapter != address(0));

    _mockSetLinkedAdapter(_linkedAdapter);

    // Mocking calls
    vm.mockCall(
      address(_bridgedUSDC),
      abi.encodeWithSignature('transferFrom(address,address,uint256)', _user, address(adapter), _amount),
      abi.encode(true)
    );
    vm.mockCall(
      address(_bridgedUSDC), abi.encodeWithSignature('burn(address,uint256)', address(adapter), _amount), abi.encode()
    );
    vm.mockCall(
      address(_messenger),
      abi.encodeWithSignature(
        'sendMessage(address,bytes,uint32)',
        _linkedAdapter,
        abi.encodeWithSignature('receiveMessage(address,uint256)', _user, _amount),
        _minGasLimit
      ),
      abi.encode(true)
    );

    // Expecting calls
    vm.expectCall(
      address(_bridgedUSDC),
      abi.encodeWithSignature('transferFrom(address,address,uint256)', _user, address(adapter), _amount)
    );

    vm.expectCall(address(_bridgedUSDC), abi.encodeWithSignature('burn(address,uint256)', address(adapter), _amount));

    vm.expectCall(
      address(_messenger),
      abi.encodeWithSignature(
        'sendMessage(address,bytes,uint32)',
        _linkedAdapter,
        abi.encodeWithSignature('receiveMessage(address,uint256)', _user, _amount),
        _minGasLimit
      )
    );

    vm.prank(_user);
    adapter.send(false, _amount, _minGasLimit);
  }

  function testSendingMessageEmitsEvent(uint256 _amount, uint32 _minGasLimit, address _linkedAdapter) public {
    vm.assume(_linkedAdapter != address(0));
    _mockSetLinkedAdapter(_linkedAdapter);

    vm.mockCall(
      address(_bridgedUSDC),
      abi.encodeWithSignature('transferFrom(address,address,uint256)', _user, address(adapter), _amount),
      abi.encode(true)
    );
    vm.mockCall(
      address(_bridgedUSDC), abi.encodeWithSignature('burn(address,uint256)', address(adapter), _amount), abi.encode()
    );
    vm.mockCall(
      address(_messenger),
      abi.encodeWithSignature(
        'sendMessage(address,bytes,uint32)',
        _linkedAdapter,
        abi.encodeWithSignature('receiveMessage(address,uint256)', _user, _amount),
        _minGasLimit
      ),
      abi.encode(true)
    );

    vm.expectEmit(true, true, true, true);
    emit MessageSent(_user, _amount, _minGasLimit);
    vm.prank(_user);
    adapter.send(false, _amount, _minGasLimit);
  }

  function testSendingMessageWithCanonicalUSDC(uint256 _amount, uint32 _minGasLimit, address _linkedAdapter) public {
    vm.assume(_linkedAdapter != address(0));
    _mockSetLinkedAdapter(_linkedAdapter);

    // Mocking calls
    vm.mockCall(_lockbox, abi.encodeWithSignature('ERC20()'), abi.encode(_l1USDC));
    vm.mockCall(
      _l1USDC,
      abi.encodeWithSignature('transferFrom(address,address,uint256)', _user, address(adapter), _amount),
      abi.encode(true)
    );
    vm.mockCall(_lockbox, abi.encodeWithSignature('deposit(uint256)', _amount), abi.encode());
    vm.mockCall(
      address(_bridgedUSDC), abi.encodeWithSignature('burn(address,uint256)', address(adapter), _amount), abi.encode()
    );
    vm.mockCall(
      address(_messenger),
      abi.encodeWithSignature(
        'sendMessage(address,bytes,uint32)',
        _linkedAdapter,
        abi.encodeWithSignature('receiveMessage(address,uint256)', _user, _amount),
        _minGasLimit
      ),
      abi.encode(true)
    );

    // Expecting calls
    vm.expectCall(
      address(_l1USDC),
      abi.encodeWithSignature('transferFrom(address,address,uint256)', _user, address(adapter), _amount)
    );

    vm.expectCall(address(_lockbox), abi.encodeWithSignature('deposit(uint256)', _amount));

    vm.expectCall(address(_bridgedUSDC), abi.encodeWithSignature('burn(address,uint256)', address(adapter), _amount));

    vm.expectCall(
      address(_messenger),
      abi.encodeWithSignature(
        'sendMessage(address,bytes,uint32)',
        _linkedAdapter,
        abi.encodeWithSignature('receiveMessage(address,uint256)', _user, _amount),
        _minGasLimit
      )
    );

    vm.prank(_user);
    adapter.send(true, _amount, _minGasLimit);
  }

  function testRevertsIfSendingCanonicalFromL2(uint256 _amount, uint32 _minGasLimit, address _linkedAdapter) public {
    // Uses test adapter so cant use helper functions
    OpUSDCBridgeAdapter _adapter = new OpUSDCBridgeAdapter(_bridgedUSDC, address(0), _messenger);

    vm.assume(_linkedAdapter != address(0));
    vm.mockCall(address(_bridgedUSDC), abi.encodeWithSignature('owner()'), abi.encode(_owner));
    vm.prank(_owner);
    _adapter.setLinkedAdapter(_linkedAdapter);

    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_OnlyOnL1.selector);
    vm.prank(_user);
    _adapter.send(true, _amount, _minGasLimit);
  }

  function testRecievingMessageRevertsIfMessengerIsntCaller(
    address _user,
    uint256 _amount,
    address _linkedAdapter
  ) public {
    vm.assume(_linkedAdapter != address(0));
    _mockSetLinkedAdapter(_linkedAdapter);

    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_NotLinkedAdapter.selector);
    vm.prank(_owner);
    adapter.receiveMessage(_user, _amount);
  }

  function testRecievingMesseageRevertsIfLinkedAdapterDidntSendMessage(
    address _user,
    uint256 _amount,
    address _randomAddr,
    address _linkedAdapter
  ) public {
    vm.assume(_randomAddr != _messenger);
    vm.assume(_linkedAdapter != address(0) && _linkedAdapter != _randomAddr);
    _mockSetLinkedAdapter(_linkedAdapter);

    vm.mockCall(_messenger, abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_randomAddr));

    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_NotLinkedAdapter.selector);
    vm.prank(_messenger);
    adapter.receiveMessage(_user, _amount);
  }

  function testRecievingMessageRevertsIfAdapterNotSet(address _user, uint256 _amount) public {
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_LinkedAdapterNotSet.selector);
    vm.prank(_owner);
    adapter.receiveMessage(_user, _amount);
  }

  function testReceiveMessageOnL1(address _user, uint256 _amount, address _linkedAdapter) public {
    vm.assume(_linkedAdapter != address(0));
    _mockSetLinkedAdapter(_linkedAdapter);

    // Mocking calls
    vm.mockCall(_messenger, abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_linkedAdapter));
    vm.mockCall(
      address(_bridgedUSDC), abi.encodeWithSignature('mint(address,uint256)', address(adapter), _amount), abi.encode()
    );
    vm.mockCall(_lockbox, abi.encodeWithSignature('withdrawTo(address,uint256)', _user, _amount), abi.encode());

    // Expecting calls
    vm.expectCall(_messenger, abi.encodeWithSignature('xDomainMessageSender()'));

    vm.expectCall(address(_bridgedUSDC), abi.encodeWithSignature('mint(address,uint256)', address(adapter), _amount));

    vm.expectCall(_lockbox, abi.encodeWithSignature('withdrawTo(address,uint256)', _user, _amount));

    vm.prank(_messenger);
    adapter.receiveMessage(_user, _amount);
  }

  function testReceiveMesseageEmitsEvent(address _user, uint256 _amount, address _linkedAdapter) public {
    vm.assume(_linkedAdapter != address(0));
    _mockSetLinkedAdapter(_linkedAdapter);

    // Mocking calls
    vm.mockCall(_messenger, abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_linkedAdapter));
    vm.mockCall(
      address(_bridgedUSDC), abi.encodeWithSignature('mint(address,uint256)', address(adapter), _amount), abi.encode()
    );
    vm.mockCall(_lockbox, abi.encodeWithSignature('withdrawTo(address,uint256)', _user, _amount), abi.encode());

    vm.expectEmit(true, true, true, true);
    emit MessageRecieved(_user, _amount);
    vm.prank(_messenger);
    adapter.receiveMessage(_user, _amount);
  }

  function testReceiveMessageOnL2(address _user, uint256 _amount, address _linkedAdapter) public {
    // Uses test adapter so cant use helper functions
    OpUSDCBridgeAdapter _adapter = new OpUSDCBridgeAdapter(_bridgedUSDC, address(0), _messenger);

    vm.assume(_linkedAdapter != address(0));
    vm.mockCall(address(_bridgedUSDC), abi.encodeWithSignature('owner()'), abi.encode(_owner));
    vm.prank(_owner);
    _adapter.setLinkedAdapter(_linkedAdapter);

    // Mocking calls
    vm.mockCall(_messenger, abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_linkedAdapter));
    vm.mockCall(
      address(_bridgedUSDC), abi.encodeWithSignature('mint(address,uint256)', address(_adapter), _amount), abi.encode()
    );
    vm.mockCall(
      address(_bridgedUSDC), abi.encodeWithSignature('transfer(address,uint256)', _user, _amount), abi.encode(true)
    );

    // Expecting calls
    vm.expectCall(address(_bridgedUSDC), abi.encodeWithSignature('mint(address,uint256)', address(_adapter), _amount));

    vm.expectCall(address(_bridgedUSDC), abi.encodeWithSignature('transfer(address,uint256)', _user, _amount));

    vm.prank(_messenger);
    _adapter.receiveMessage(_user, _amount);
  }

  function _mockSetLinkedAdapter(address _linkedAdapter) internal {
    vm.mockCall(address(_bridgedUSDC), abi.encodeWithSignature('owner()'), abi.encode(_owner));
    vm.prank(_owner);
    adapter.setLinkedAdapter(_linkedAdapter);
  }
}
