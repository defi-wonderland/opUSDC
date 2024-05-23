pragma solidity ^0.8.25;

import {ERC1967Proxy} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import {IL1OpUSDCBridgeAdapter, L1OpUSDCBridgeAdapter} from 'contracts/L1OpUSDCBridgeAdapter.sol';
import {IOpUSDCBridgeAdapter} from 'interfaces/IOpUSDCBridgeAdapter.sol';
import {Helpers} from 'test/utils/Helpers.sol';

contract ForTestL1OpUSDCBridgeAdapter is L1OpUSDCBridgeAdapter {
  constructor(
    address _usdc,
    address _linkedAdapter,
    address _upgradeManager,
    address _factory
  ) L1OpUSDCBridgeAdapter(_usdc, _linkedAdapter, _upgradeManager, _factory) {}

  function forTest_setBurnAmount(uint256 _amount) external {
    burnAmount = _amount;
  }

  function forTest_setCircle(address _circle) external {
    circle = _circle;
  }

  function forTest_setMessagerStatus(address _messenger, Status _status) external {
    messengerStatus[_messenger] = _status;
  }
}

abstract contract Base is Helpers {
  ForTestL1OpUSDCBridgeAdapter public adapter;
  ForTestL1OpUSDCBridgeAdapter public implementation;

  address internal _user = makeAddr('user');
  address internal _signerAd;
  uint256 internal _signerPk;
  address internal _usdc = makeAddr('opUSDC');
  address internal _linkedAdapter = makeAddr('linkedAdapter');
  address internal _upgradeManager = makeAddr('upgradeManager');
  address internal _factory = makeAddr('factory');

  // cant fuzz this because of foundry's VM
  address internal _messenger = makeAddr('messenger');

  event MessageSent(address _user, address _to, uint256 _amount, address _messenger, uint32 _minGasLimit);
  event MessageReceived(address _user, uint256 _amount, address _messenger);
  event BurnAmountSet(uint256 _burnAmount);
  event L2AdapterUpgradeSent(address _newImplementation, address _messenger, bytes _data, uint32 _minGasLimit);
  event CircleSet(address _circle);
  event MessengerInitialized(address _messenger);

  function setUp() public virtual {
    (_signerAd, _signerPk) = makeAddrAndKey('signer');
    vm.etch(_messenger, 'xDomainMessageSender');
    implementation = new ForTestL1OpUSDCBridgeAdapter(_usdc, _linkedAdapter, _upgradeManager, _factory);
    adapter = ForTestL1OpUSDCBridgeAdapter(address(new ERC1967Proxy(address(implementation), '')));
  }
}

contract L1OpUSDCBridgeAdapter_Unit_Constructor is Base {
  /**
   * @notice Check that the constructor works as expected
   */
  function test_constructorParams() public {
    assertEq(adapter.UPGRADE_MANAGER(), _upgradeManager, 'Owner should be set to the deployer');
    assertEq(adapter.USDC(), _usdc, 'USDC should be set to the provided address');
    assertEq(adapter.LINKED_ADAPTER(), _linkedAdapter, 'Linked adapter should be set to the provided address');
    assertEq(adapter.FACTORY(), _factory, 'Factory should be set to the provided address');
  }
}

contract L1OpUSDCBridgeAdapter_Unit_SetBurnAmount is Base {
  /**
   * @notice Check that only the owner can set the burn amount
   */
  function test_onlyUpgradeManager() external {
    // Execute
    vm.prank(_user);
    vm.expectRevert(abi.encodeWithSelector(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidSender.selector));
    adapter.setBurnAmount(0);
  }

  /**
   * @notice Check that the burn amount is set as expected
   */
  function test_setAmount(uint256 _burnAmount) external {
    // Execute
    vm.prank(_upgradeManager);
    adapter.setBurnAmount(_burnAmount);

    // Assert
    assertEq(adapter.burnAmount(), _burnAmount, 'Burn amount should be set');
  }

  /**
   * @notice Check that the event is emitted as expected
   */
  function test_emitEvent(uint256 _burnAmount) external {
    // Execute
    vm.prank(_upgradeManager);
    vm.expectEmit(true, true, true, true);
    emit BurnAmountSet(_burnAmount);
    adapter.setBurnAmount(_burnAmount);
  }
}

contract L1OpUSDCBridgeAdapter_Unit_SetCircle is Base {
  /**
   * @notice Check that only the owner can set the circle
   */
  function test_onlyUpgradeManager() external {
    // Execute
    vm.prank(_user);
    vm.expectRevert(abi.encodeWithSelector(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidSender.selector));
    adapter.setCircle(address(0));
  }

  /**
   * @notice Check that the circle is set as expected
   */
  function test_setCircle(address _circle) external {
    // Execute
    vm.prank(_upgradeManager);
    adapter.setCircle(_circle);

    // Assert
    assertEq(adapter.circle(), _circle, 'Circle should be set');
  }

  /**
   * @notice Check that the event is emitted as expected
   */
  function test_emitEvent(address _circle) external {
    // Execute
    vm.prank(_upgradeManager);
    vm.expectEmit(true, true, true, true);
    emit CircleSet(_circle);
    adapter.setCircle(_circle);
  }
}

contract L1OpUSDCBridgeAdapter_Unit_BurnLockedUSDC is Base {
  /**
   * @notice Check that only the owner can burn the locked USDC
   */
  function test_onlyCircle() external {
    // Execute
    vm.prank(_user);
    vm.expectRevert(abi.encodeWithSelector(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidSender.selector));
    adapter.burnLockedUSDC();
  }

  /**
   * @notice Check that the burn function is called as expected
   */
  function test_expectedCall(uint256 _burnAmount, address _circle) external {
    adapter.forTest_setCircle(_circle);

    vm.assume(_burnAmount > 0);

    _mockAndExpect(
      address(_usdc), abi.encodeWithSignature('burn(address,uint256)', address(adapter), _burnAmount), abi.encode(true)
    );

    adapter.forTest_setBurnAmount(_burnAmount);

    // Execute
    vm.prank(_circle);
    adapter.burnLockedUSDC();
  }

  /**
   * @notice Check that the burn amount is set to 0 after burning
   */
  function test_resetStorageValues(uint256 _burnAmount, address _circle) external {
    vm.assume(_burnAmount > 0);
    adapter.forTest_setCircle(_circle);

    vm.mockCall(
      address(_usdc), abi.encodeWithSignature('burn(address,uint256)', address(adapter), _burnAmount), abi.encode(true)
    );

    adapter.forTest_setBurnAmount(_burnAmount);

    // Execute
    vm.prank(_circle);
    adapter.burnLockedUSDC();

    assertEq(adapter.burnAmount(), 0, 'Burn amount should be set to 0');
    assertEq(adapter.circle(), address(0), 'Circle should be set to 0');
  }
}

contract L1OpUSDCBridgeAdapter_Unit_InitalizeNewMessenger is Base {
  /**
   * @notice Check that only the owner can initalize a new messenger
   */
  function test_onlyFactory(address _newMessenger) external {
    // Execute
    vm.prank(_user);
    vm.expectRevert(abi.encodeWithSelector(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidSender.selector));
    adapter.initalizeNewMessenger(_newMessenger);
  }

  /**
   * @notice Check that the messenger reverts if its already initialized
   */
  function test_revertIfMessengerAlreadyInitialized(address _newMessenger) external {
    adapter.forTest_setMessagerStatus(_newMessenger, IL1OpUSDCBridgeAdapter.Status.Active);

    // Execute
    vm.prank(_factory);
    vm.expectRevert(IL1OpUSDCBridgeAdapter.IL1OpUSDCBridgeAdapter_MessengerAlreadyInitialized.selector);
    adapter.initalizeNewMessenger(_newMessenger);
  }

  /**
   * @notice Check that the messenger is set as expected
   */
  function test_setMessengerStatus(address _newMessenger) external {
    // Execute
    vm.prank(_factory);
    adapter.initalizeNewMessenger(_newMessenger);

    // Assert
    assertEq(
      uint256(adapter.messengerStatus(_newMessenger)),
      uint256(IL1OpUSDCBridgeAdapter.Status.Active),
      'Messenger should be set'
    );
  }

  /**
   * @notice Check that the event is emitted as expected
   */
  function test_emitEvent(address _newMessenger) external {
    // Execute
    vm.prank(_factory);
    vm.expectEmit(true, true, true, true);
    emit MessengerInitialized(_newMessenger);
    adapter.initalizeNewMessenger(_newMessenger);
  }
}

contract L1OpUSDCBridgeAdapter_Unit_SendMessage is Base {
  /**
   * @notice Check that the function reverts if messager is not active
   */
  function test_revertOnMessengerNotActive(address _to, uint256 _amount, uint32 _minGasLimit) external {
    // Execute
    vm.prank(_user);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_MessagingDisabled.selector);
    adapter.sendMessage(_to, _amount, _messenger, _minGasLimit);
  }

  /**
   * @notice Check that transferFrom and sendMessage are called as expected
   */
  function test_expectedCall(address _to, uint256 _amount, uint32 _minGasLimit) external {
    adapter.forTest_setMessagerStatus(_messenger, IL1OpUSDCBridgeAdapter.Status.Active);
    _mockAndExpect(
      address(_usdc),
      abi.encodeWithSignature('transferFrom(address,address,uint256)', _user, address(adapter), _amount),
      abi.encode(true)
    );
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
    adapter.sendMessage(_to, _amount, _messenger, _minGasLimit);
  }

  /**
   * @notice Check that the event is emitted as expected
   */
  function test_emitEvent(address _to, uint256 _amount, uint32 _minGasLimit) external {
    adapter.forTest_setMessagerStatus(_messenger, IL1OpUSDCBridgeAdapter.Status.Active);
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
        abi.encodeWithSignature('receiveMessage(address,uint256)', _to, _amount),
        _minGasLimit
      ),
      abi.encode()
    );

    // Expect events
    vm.expectEmit(true, true, true, true);
    emit MessageSent(_user, _to, _amount, _messenger, _minGasLimit);

    // Execute
    vm.prank(_user);
    adapter.sendMessage(_to, _amount, _messenger, _minGasLimit);
  }
}

contract L1OpUSDCBridgeAdapter_Unit_SendMessageWithSignature is Base {
  /**
   * @notice Check that the function reverts if messaging is disabled
   */
  function test_revertOnMessengerNotActive(
    address _to,
    uint256 _amount,
    uint256 _nonce,
    bytes memory _signature,
    uint32 _minGasLimit
  ) external {
    // Execute
    vm.prank(_user);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_MessagingDisabled.selector);
    adapter.sendMessage(_to, _amount, _messenger, _nonce, _signature, _minGasLimit);
  }

  /**
   * @notice Check that function reverts when the nonce is invalid
   */
  function test_revertOnInvalidNonce(address _to, uint256 _amount, uint256 _nonce, uint32 _minGasLimit) external {
    vm.assume(_nonce != adapter.userNonce(_signerAd));
    bytes memory _signature = _generateSignature(_to, _amount, _nonce, _signerAd, _signerPk, address(adapter));
    adapter.forTest_setMessagerStatus(_messenger, IL1OpUSDCBridgeAdapter.Status.Active);

    // Execute
    vm.prank(_user);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidNonce.selector);
    adapter.sendMessage(_to, _amount, _messenger, _nonce, _signature, _minGasLimit);
  }

  /**
   * @notice Check that transferFrom and sendMessage are called as expected
   */
  function test_expectedCall(address _to, uint256 _amount, uint32 _minGasLimit) external {
    uint256 _nonce = adapter.userNonce(_signerAd);
    bytes memory _signature = _generateSignature(_to, _amount, _nonce, _signerAd, _signerPk, address(adapter));
    adapter.forTest_setMessagerStatus(_messenger, IL1OpUSDCBridgeAdapter.Status.Active);
    _mockAndExpect(
      address(_usdc),
      abi.encodeWithSignature('transferFrom(address,address,uint256)', _signerAd, address(adapter), _amount),
      abi.encode(true)
    );
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
    adapter.sendMessage(_to, _amount, _messenger, _nonce, _signature, _minGasLimit);
  }

  /**
   * @notice Check that the event is emitted as expected
   */
  function test_emitEvent(address _to, uint256 _amount, uint32 _minGasLimit) external {
    uint256 _nonce = adapter.userNonce(_signerAd);
    bytes memory _signature = _generateSignature(_to, _amount, _nonce, _signerAd, _signerPk, address(adapter));
    adapter.forTest_setMessagerStatus(_messenger, IL1OpUSDCBridgeAdapter.Status.Active);
    vm.mockCall(
      address(_usdc),
      abi.encodeWithSignature('transferFrom(address,address,uint256)', _signerAd, address(adapter), _amount),
      abi.encode(true)
    );
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
    emit MessageSent(_signerAd, _to, _amount, _messenger, _minGasLimit);
    // Execute
    vm.prank(_user);
    adapter.sendMessage(_to, _amount, _messenger, _nonce, _signature, _minGasLimit);
  }
}

contract L1OpUSDCBridgeAdapter_Unit_SendL2AdapterUpgrade is Base {
  /**
   * @notice Check that only the owner can send an upgrade message
   */
  function test_onlyUpgradeManager(address _newImplementation, bytes memory _data, uint32 _minGasLimit) external {
    // Execute
    vm.prank(_user);
    vm.expectRevert(abi.encodeWithSelector(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidSender.selector));
    adapter.sendL2AdapterUpgrade(_newImplementation, _messenger, _data, _minGasLimit);
  }

  /**
   * @notice Check that the function reverts if a messenger is unitialized
   */
  function test_revertOnMessagingUnintialized(
    address _newImplementation,
    bytes memory _data,
    uint32 _minGasLimit
  ) external {
    // Execute
    vm.prank(_upgradeManager);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_MessagingDisabled.selector);
    adapter.sendL2AdapterUpgrade(_newImplementation, _messenger, _data, _minGasLimit);
  }

  /**
   * @notice Check that the message is sent as expected
   */
  function test_expectedCall(address _newImplementation, bytes memory _data, uint32 _minGasLimit) external {
    adapter.forTest_setMessagerStatus(_messenger, IL1OpUSDCBridgeAdapter.Status.Active);

    _mockAndExpect(
      address(_messenger),
      abi.encodeWithSignature(
        'sendMessage(address,bytes,uint32)',
        _linkedAdapter,
        abi.encodeWithSignature('upgradeToAndCall(address,bytes)', _newImplementation, _data),
        _minGasLimit
      ),
      abi.encode()
    );

    // Execute
    vm.prank(_upgradeManager);
    adapter.sendL2AdapterUpgrade(_newImplementation, _messenger, _data, _minGasLimit);
  }

  /**
   * @notice Check that the event is emitted as expected
   */
  function test_emitEvent(address _newImplementation, bytes memory _data, uint32 _minGasLimit) external {
    adapter.forTest_setMessagerStatus(_messenger, IL1OpUSDCBridgeAdapter.Status.Active);

    // Mock calls
    vm.mockCall(
      address(_messenger),
      abi.encodeWithSignature(
        'sendMessage(address,bytes,uint32)',
        _linkedAdapter,
        abi.encodeWithSignature('upgradeToAndCall(address,bytes)', _newImplementation, _data),
        _minGasLimit
      ),
      abi.encode()
    );

    // Expect events
    vm.expectEmit(true, true, true, true);
    emit L2AdapterUpgradeSent(_newImplementation, _messenger, _data, _minGasLimit);

    // Execute
    vm.prank(_upgradeManager);
    adapter.sendL2AdapterUpgrade(_newImplementation, _messenger, _data, _minGasLimit);
  }
}

contract L1OpUSDCBridgeAdapter_Unit_ReceiveMessage is Base {
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
    vm.assume(_messageSender != _linkedAdapter);
    // Mock calls
    vm.mockCall(address(_messenger), abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_messageSender));

    // Execute
    vm.prank(_messenger);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidSender.selector);
    adapter.receiveMessage(_user, _amount);
  }

  /**
   * @notice Check that token transfer is called as expected
   */
  function test_sendTokens(uint256 _amount) external {
    adapter.forTest_setMessagerStatus(_messenger, IL1OpUSDCBridgeAdapter.Status.Active);

    // Mock calls
    vm.mockCall(address(_messenger), abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_linkedAdapter));

    _mockAndExpect(
      address(_usdc), abi.encodeWithSignature('transfer(address,uint256)', _user, _amount), abi.encode(true)
    );

    // Execute
    vm.prank(_messenger);
    adapter.receiveMessage(_user, _amount);
  }

  /**
   * @notice Check that the event is emitted as expected
   */
  function test_emitEvent(uint256 _amount) external {
    adapter.forTest_setMessagerStatus(_messenger, IL1OpUSDCBridgeAdapter.Status.Active);

    // Mock calls
    vm.mockCall(address(_messenger), abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_linkedAdapter));

    vm.mockCall(address(_usdc), abi.encodeWithSignature('transfer(address,uint256)', _user, _amount), abi.encode(true));

    // Execute
    vm.expectEmit(true, true, true, true);
    emit MessageReceived(_user, _amount, _messenger);

    vm.prank(_messenger);
    adapter.receiveMessage(_user, _amount);
  }
}

contract L1OpUSDCBridgeAdapter_Unit_StopMessaging is Base {
  event MessagingStopped(address _messenger);

  /**
   * @notice Check that only the owner can stop messaging
   */
  function test_onlyUpgradeManager() public {
    // Execute
    vm.prank(_user);
    vm.expectRevert(abi.encodeWithSelector(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidSender.selector));
    adapter.stopMessaging(0, _messenger);
  }

  /**
   * @notice Check that the function reverts if messaging is already disabled
   */
  function test_revertIfMessagingIsAlreadyDisabled(uint32 _minGasLimit) public {
    // Execute
    vm.prank(_upgradeManager);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_MessagingDisabled.selector);
    adapter.stopMessaging(_minGasLimit, _messenger);
  }

  /**
   * @notice Check that messenger status gets set to paused
   */
  function test_setMessengerStatusToPaused(uint32 _minGasLimit) public {
    adapter.forTest_setMessagerStatus(_messenger, IL1OpUSDCBridgeAdapter.Status.Active);

    bytes memory _messageData = abi.encodeWithSignature('receiveStopMessaging()');

    _mockAndExpect(
      _messenger,
      abi.encodeWithSignature('sendMessage(address,bytes,uint32)', _linkedAdapter, _messageData, _minGasLimit),
      abi.encode('')
    );

    // Execute
    vm.prank(_upgradeManager);
    adapter.stopMessaging(_minGasLimit, _messenger);
    assertEq(
      uint256(adapter.messengerStatus(_messenger)),
      uint256(IL1OpUSDCBridgeAdapter.Status.Paused),
      'Messaging should be disabled'
    );
  }

  /**
   * @notice Check that the event is emitted as expected
   */
  function test_emitEvent(uint32 _minGasLimit) public {
    adapter.forTest_setMessagerStatus(_messenger, IL1OpUSDCBridgeAdapter.Status.Active);

    bytes memory _messageData = abi.encodeWithSignature('receiveStopMessaging()');

    /// Mock calls
    vm.mockCall(
      _messenger,
      abi.encodeWithSignature('sendMessage(address,bytes,uint32)', _linkedAdapter, _messageData, _minGasLimit),
      abi.encode('')
    );

    // Expect events
    vm.expectEmit(true, true, true, true);
    emit MessagingStopped(_messenger);

    // Execute
    vm.prank(_upgradeManager);
    adapter.stopMessaging(_minGasLimit, _messenger);
  }
}

contract L1OpUSDCBridgeAdapter_Unit_UpgradeToAndCall is Base {
  /**
   * @notice Check that only the owner can upgrade the contract
   */
  function test_onlyUpgradeManager(address _newImplementation) external {
    // Execute
    vm.prank(_user);
    vm.expectRevert(abi.encodeWithSelector(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidSender.selector));
    adapter.upgradeToAndCall(_newImplementation, '');
  }

  /**
   * @notice Check that the upgrade is authorized as expected
   */
  function test_authorizeUpgrade() external {
    address _newImplementation =
      address(new ForTestL1OpUSDCBridgeAdapter(_usdc, _linkedAdapter, _upgradeManager, _factory));
    // Execute
    vm.prank(_upgradeManager);
    adapter.upgradeToAndCall(_newImplementation, '');
  }
}
