pragma solidity ^0.8.25;

import {ERC1967Proxy} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import {IL1OpUSDCBridgeAdapter, L1OpUSDCBridgeAdapter} from 'contracts/L1OpUSDCBridgeAdapter.sol';
import {L1OpUSDCFactory} from 'contracts/L1OpUSDCFactory.sol';
import {IOpUSDCBridgeAdapter} from 'interfaces/IOpUSDCBridgeAdapter.sol';
import {IUpgradeManager} from 'interfaces/IUpgradeManager.sol';
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
  L1OpUSDCFactory public factory;

  address internal _user = makeAddr('user');
  address internal _signerAd;
  uint256 internal _signerPk;
  address internal _usdc = makeAddr('opUSDC');
  address internal _linkedAdapter = makeAddr('linkedAdapter');
  address internal _upgradeManager;
  address internal _factory;

  address internal _l2AdapterImplAddress = makeAddr('l2AdapterImpl');
  bytes internal _l2AdapterBytecode = '0x608061111111';
  bytes internal _l2AdapterInitTx = 'tx2';
  bytes[] internal _l2AdapterInitTxs;
  IUpgradeManager.Implementation internal _l2AdapterImplementation;

  address internal _l2UsdcImplAddress = makeAddr('l2UsdcImpl');
  bytes internal _l2UsdcBytecode = '0x608061111111';
  bytes internal _l2UsdcInitTx = 'tx2';
  bytes[] internal _l2UsdcInitTxs;
  IUpgradeManager.Implementation internal _l2UsdcImplementation;

  // cant fuzz this because of foundry's VM
  address internal _messenger = makeAddr('messenger');

  event MessageSent(address _user, address _to, uint256 _amount, address _messenger, uint32 _minGasLimit);
  event MessageReceived(address _user, uint256 _amount, address _messenger);
  event BurnAmountSet(uint256 _burnAmount);
  event L2AdapterUpgradeSent(address _newImplementation, address _messenger, uint32 _minGasLimit);
  event L2UsdcUpgradeSent(address _newImplementation, address _messenger, uint32 _minGasLimit);
  event MessengerInitialized(address _messenger);
  event MigratingToNative(address _messenger, address _newOwner);

  function setUp() public virtual {
    // Deploy factory
    factory = new L1OpUSDCFactory(_usdc, address(this));
    _upgradeManager = address(factory.UPGRADE_MANAGER());

    // Set the bytecode to the implementation addresses
    vm.etch(_l2AdapterImplAddress, _l2AdapterBytecode);
    vm.etch(_l2UsdcImplAddress, _l2UsdcBytecode);

    // Define the implementation structs info
    _l2AdapterInitTxs.push(_l2AdapterInitTx);
    IUpgradeManager(_upgradeManager).setL2AdapterImplementation(_l2AdapterImplAddress, _l2AdapterInitTxs);

    _l2UsdcInitTxs.push(_l2UsdcInitTx);
    IUpgradeManager(_upgradeManager).setBridgedUSDCImplementation(_l2UsdcImplAddress, _l2UsdcInitTxs);

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
   * @notice Check that the function reverts if the messenger is not in an upgrading state
   */
  function test_revertIfMessengerNotUpgrading(uint256 _amount) external {
    vm.mockCall(address(_messenger), abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_linkedAdapter));
    // Execute
    vm.prank(_messenger);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidSender.selector);
    adapter.setBurnAmount(_amount);
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
    adapter.setBurnAmount(_amount);
  }

  /**
   * @notice Check that the burn amount is set as expected
   */
  function test_setAmount(uint256 _burnAmount) external {
    adapter.forTest_setMessagerStatus(_messenger, IL1OpUSDCBridgeAdapter.Status.Upgrading);
    vm.mockCall(address(_messenger), abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_linkedAdapter));

    // Execute
    vm.prank(_messenger);
    adapter.setBurnAmount(_burnAmount);

    // Assert
    assertEq(adapter.burnAmount(), _burnAmount, 'Burn amount should be set');
    assertEq(
      uint256(adapter.messengerStatus(_messenger)),
      uint256(IL1OpUSDCBridgeAdapter.Status.Deprecated),
      'Messenger should be set to deprecated'
    );
  }

  /**
   * @notice Check that the event is emitted as expected
   */
  function test_emitEvent(uint256 _burnAmount) external {
    adapter.forTest_setMessagerStatus(_messenger, IL1OpUSDCBridgeAdapter.Status.Upgrading);
    vm.mockCall(address(_messenger), abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_linkedAdapter));

    // Execute
    vm.prank(_messenger);
    vm.expectEmit(true, true, true, true);
    emit BurnAmountSet(_burnAmount);
    adapter.setBurnAmount(_burnAmount);
  }
}

contract L1OpUSDCBridgeAdapter_Unit_ResumeMessaging is Base {
  event MessagingResumed(address _messenger);

  /**
   * @notice Check that only the upgrade manager can resume messaging
   */
  function test_onlyUpgradeManager(uint32 _minGasLimit) external {
    // Execute
    vm.prank(_user);
    vm.expectRevert(abi.encodeWithSelector(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidSender.selector));
    adapter.resumeMessaging(_messenger, _minGasLimit);
  }

  /**
   * @notice Check that it reverts if bridging is not paused
   */
  function test_RevertIfBridgingIsNotPaused(uint32 _minGasLimit) external {
    // Execute
    vm.prank(_upgradeManager);
    vm.expectRevert(IL1OpUSDCBridgeAdapter.IL1OpUSDCBridgeAdapter_MessengerNotPaused.selector);
    adapter.resumeMessaging(_messenger, _minGasLimit);
  }

  /**
   * @notice Check that the messenger status is set to active
   */
  function test_setMessengerStatusToActive(uint32 _minGasLimit) external {
    adapter.forTest_setMessagerStatus(_messenger, IL1OpUSDCBridgeAdapter.Status.Paused);

    _mockAndExpect(
      address(_messenger),
      abi.encodeWithSignature(
        'sendMessage(address,bytes,uint32)',
        _linkedAdapter,
        abi.encodeWithSignature('receiveResumeMessaging()'),
        _minGasLimit
      ),
      abi.encode('')
    );

    // Execute
    vm.prank(_upgradeManager);
    adapter.resumeMessaging(_messenger, _minGasLimit);
    assertEq(
      uint256(adapter.messengerStatus(_messenger)),
      uint256(IL1OpUSDCBridgeAdapter.Status.Active),
      'Messaging should be enabled'
    );
  }

  /**
   * @notice Check that the event is emitted as expected
   */
  function test_emitEvent(uint32 _minGasLimit) external {
    adapter.forTest_setMessagerStatus(_messenger, IL1OpUSDCBridgeAdapter.Status.Paused);

    // Mock calls
    vm.mockCall(
      address(_messenger),
      abi.encodeWithSignature(
        'sendMessage(address,bytes,uint32)',
        _linkedAdapter,
        abi.encodeWithSignature('receiveResumeMessaging()'),
        _minGasLimit
      ),
      abi.encode('')
    );

    // Expect events
    vm.expectEmit(true, true, true, true);
    emit MessagingResumed(_messenger);

    // Execute
    vm.prank(_upgradeManager);
    adapter.resumeMessaging(_messenger, _minGasLimit);
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
    bytes memory _signature,
    uint256 _deadline,
    uint32 _minGasLimit
  ) external {
    // Execute
    vm.prank(_user);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_MessagingDisabled.selector);
    adapter.sendMessage(_signerAd, _to, _amount, _messenger, _signature, _deadline, _minGasLimit);
  }

  /**
   * @notice Check that the function reverts if the deadline is in the past
   */
  function test_revertOnMessengerExpired(
    address _to,
    uint256 _amount,
    bytes memory _signature,
    uint256 _timestamp,
    uint256 _deadline,
    uint32 _minGasLimit
  ) external {
    vm.assume(_timestamp > _deadline);
    vm.warp(_timestamp);

    adapter.forTest_setMessagerStatus(_messenger, IL1OpUSDCBridgeAdapter.Status.Active);
    // Execute
    vm.prank(_user);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_MessageExpired.selector);
    adapter.sendMessage(_signerAd, _to, _amount, _messenger, _signature, _deadline, _minGasLimit);
  }

  /**
   * @notice Check that the function reverts on invalid signature
   */
  function test_invalidSignature(address _to, uint256 _amount, uint256 _deadline, uint32 _minGasLimit) external {
    vm.assume(_deadline >= block.timestamp);
    uint256 _nonce = adapter.userNonce(_signerAd);
    (address _notSignerAd, uint256 _notSignerPk) = makeAddrAndKey('notSigner');
    bytes memory _signature = _generateSignature(_to, _amount, _nonce, _notSignerAd, _notSignerPk, address(adapter));
    adapter.forTest_setMessagerStatus(_messenger, IL1OpUSDCBridgeAdapter.Status.Active);

    // Execute
    vm.prank(_user);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidSignature.selector);
    adapter.sendMessage(_signerAd, _to, _amount, _messenger, _signature, _deadline, _minGasLimit);
  }

  /**
   * @notice Check nonce increment
   */
  function test_nonceIncrement(address _to, uint256 _amount, uint256 _deadline, uint32 _minGasLimit) external {
    vm.assume(_deadline >= block.timestamp);
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

    // Execute
    vm.prank(_user);
    adapter.sendMessage(_signerAd, _to, _amount, _messenger, _signature, _deadline, _minGasLimit);
    assertEq(adapter.userNonce(_signerAd), _nonce + 1, 'Nonce should be incremented');
  }

  /**
   * @notice Check that transferFrom and sendMessage are called as expected
   */
  function test_expectedCall(address _to, uint256 _amount, uint256 _deadline, uint32 _minGasLimit) external {
    vm.assume(_deadline >= block.timestamp);
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
    adapter.sendMessage(_signerAd, _to, _amount, _messenger, _signature, _deadline, _minGasLimit);
  }

  /**
   * @notice Check that the event is emitted as expected
   */
  function test_emitEvent(address _to, uint256 _amount, uint256 _deadline, uint32 _minGasLimit) external {
    vm.assume(_deadline >= block.timestamp);
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
    adapter.sendMessage(_signerAd, _to, _amount, _messenger, _signature, _deadline, _minGasLimit);
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

contract L1OpUSDCBridgeAdapter_Unit_MigrateToNative is Base {
  /**
   * @notice Check that the function reverts if the sender is not the upgrade manager
   */
  function test_onlyUpgradeManager(
    address _newOwner,
    uint32 _minGasLimitReceiveOnL2,
    uint32 _minGasLimitSetBurnAmount
  ) external {
    // Execute
    vm.prank(_user);
    vm.expectRevert(abi.encodeWithSelector(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidSender.selector));
    adapter.migrateToNative(_messenger, _newOwner, _minGasLimitReceiveOnL2, _minGasLimitSetBurnAmount);
  }

  /**
   * @notice Check that the function reverts if a messenger is not active or upgrading
   */
  function test_revertIfMessengerNotActiveOrUpgrading(
    address _newOwner,
    uint32 _minGasLimitReceiveOnL2,
    uint32 _minGasLimitSetBurnAmount
  ) external {
    // Execute
    vm.prank(_upgradeManager);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_MessagingDisabled.selector);
    adapter.migrateToNative(_messenger, _newOwner, _minGasLimitReceiveOnL2, _minGasLimitSetBurnAmount);
  }

  /**
   * @notice Check that the function reverts if a migration is in progress
   */
  function test_revertIfMigrationInProgress(
    address _newOwner,
    uint32 _minGasLimitReceiveOnL2,
    uint32 _minGasLimitSetBurnAmount,
    address _circle
  ) external {
    vm.assume(_circle != address(0));
    adapter.forTest_setMessagerStatus(_messenger, IL1OpUSDCBridgeAdapter.Status.Active);
    adapter.forTest_setCircle(_circle);
    // Execute
    vm.prank(_upgradeManager);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_MigrationInProgress.selector);
    adapter.migrateToNative(_messenger, _newOwner, _minGasLimitReceiveOnL2, _minGasLimitSetBurnAmount);
  }

  /**
   * @notice Check that the function updates the state as expected
   */
  function test_StateOfMigration(
    address _newOwner,
    uint32 _minGasLimitReceiveOnL2,
    uint32 _minGasLimitSetBurnAmount
  ) external {
    adapter.forTest_setMessagerStatus(_messenger, IL1OpUSDCBridgeAdapter.Status.Active);

    vm.mockCall(
      address(_messenger),
      abi.encodeWithSignature(
        'sendMessage(address,bytes,uint32)',
        _linkedAdapter,
        abi.encodeWithSignature('receiveMigrateToNative(address,uint32)', _newOwner, _minGasLimitSetBurnAmount),
        _minGasLimitReceiveOnL2
      ),
      abi.encode()
    );

    // Execute
    vm.prank(_upgradeManager);
    adapter.migrateToNative(_messenger, _newOwner, _minGasLimitReceiveOnL2, _minGasLimitSetBurnAmount);
    assertEq(adapter.circle(), _newOwner, 'Circle should be set to the new owner');
    assertEq(
      uint256(adapter.messengerStatus(_messenger)),
      uint256(IL1OpUSDCBridgeAdapter.Status.Upgrading),
      'Messenger should be set to deprecated'
    );
  }

  /**
   * @notice Check that the function calls the expected functions
   */
  function test_expectCall(
    address _newOwner,
    uint32 _minGasLimitReceiveOnL2,
    uint32 _minGasLimitSetBurnAmount
  ) external {
    adapter.forTest_setMessagerStatus(_messenger, IL1OpUSDCBridgeAdapter.Status.Upgrading);

    _mockAndExpect(
      address(_messenger),
      abi.encodeWithSignature(
        'sendMessage(address,bytes,uint32)',
        _linkedAdapter,
        abi.encodeWithSignature('receiveMigrateToNative(address,uint32)', _newOwner, _minGasLimitSetBurnAmount),
        _minGasLimitReceiveOnL2
      ),
      abi.encode()
    );

    // Execute
    vm.prank(_upgradeManager);
    adapter.migrateToNative(_messenger, _newOwner, _minGasLimitReceiveOnL2, _minGasLimitSetBurnAmount);
  }

  /**
   * @notice Check that we can recall the function if its upgrading
   */
  function test_recallWhenUpgrading(
    address _newOwner,
    uint32 _minGasLimitReceiveOnL2,
    uint32 _minGasLimitSetBurnAmount
  ) external {
    adapter.forTest_setMessagerStatus(_messenger, IL1OpUSDCBridgeAdapter.Status.Upgrading);
    adapter.forTest_setCircle(_newOwner);

    _mockAndExpect(
      address(_messenger),
      abi.encodeWithSignature(
        'sendMessage(address,bytes,uint32)',
        _linkedAdapter,
        abi.encodeWithSignature('receiveMigrateToNative(address,uint32)', _newOwner, _minGasLimitSetBurnAmount),
        _minGasLimitReceiveOnL2
      ),
      abi.encode()
    );

    // Execute
    vm.prank(_upgradeManager);
    adapter.migrateToNative(_messenger, _newOwner, _minGasLimitReceiveOnL2, _minGasLimitSetBurnAmount);
  }

  /**
   * @notice Check that the event is emitted as expected
   */
  function test_emitEventMigrating(
    address _newOwner,
    uint32 _minGasLimitReceiveOnL2,
    uint32 _minGasLimitSetBurnAmount
  ) external {
    adapter.forTest_setMessagerStatus(_messenger, IL1OpUSDCBridgeAdapter.Status.Active);

    // Mock calls
    vm.mockCall(
      address(_messenger),
      abi.encodeWithSignature(
        'sendMessage(address,bytes,uint32)',
        _linkedAdapter,
        abi.encodeWithSignature('receiveMigrateToNative(address,uint32)', _newOwner, _minGasLimitSetBurnAmount),
        _minGasLimitReceiveOnL2
      ),
      abi.encode()
    );

    // Expect events
    vm.expectEmit(true, true, true, true);
    emit MigratingToNative(_messenger, _newOwner);

    // Execute
    vm.prank(_upgradeManager);
    adapter.migrateToNative(_messenger, _newOwner, _minGasLimitReceiveOnL2, _minGasLimitSetBurnAmount);
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
    adapter.stopMessaging(_messenger, 0);
  }

  /**
   * @notice Check that the function reverts if messaging is already disabled
   */
  function test_revertIfMessagingIsAlreadyDisabled(uint32 _minGasLimit) public {
    // Execute
    vm.prank(_upgradeManager);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_MessagingDisabled.selector);
    adapter.stopMessaging(_messenger, _minGasLimit);
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
    adapter.stopMessaging(_messenger, _minGasLimit);
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
    adapter.stopMessaging(_messenger, _minGasLimit);
  }
}

contract L1OpUSDCBridgeAdapter_Unit_SendL2AdapterUpgrade is Base {
  /**
   * @notice Check that the function reverts if a messenger is unitialized
   */
  function test_revertOnMessagingUnintialized(uint32 _minGasLimit) external {
    // Execute
    vm.prank(_upgradeManager);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_MessagingDisabled.selector);
    adapter.sendL2AdapterUpgrade(_messenger, _minGasLimit);
  }

  /**
   * @notice Check that the message is sent as expected
   */
  function test_expectedCall(uint32 _minGasLimit) external {
    adapter.forTest_setMessagerStatus(_messenger, IL1OpUSDCBridgeAdapter.Status.Active);

    _mockAndExpect(
      address(_messenger),
      abi.encodeWithSignature(
        'sendMessage(address,bytes,uint32)',
        _linkedAdapter,
        abi.encodeWithSignature('receiveAdapterUpgrade(bytes,bytes[])', _l2AdapterBytecode, _l2AdapterInitTxs),
        _minGasLimit
      ),
      abi.encode()
    );

    // Execute
    vm.prank(_upgradeManager);
    adapter.sendL2AdapterUpgrade(_messenger, _minGasLimit);
  }

  /**
   * @notice Check that the event is emitted as expected
   */
  function test_emitEvent(uint32 _minGasLimit) external {
    adapter.forTest_setMessagerStatus(_messenger, IL1OpUSDCBridgeAdapter.Status.Active);

    // Mock calls
    vm.mockCall(
      address(_messenger),
      abi.encodeWithSignature(
        'sendMessage(address,bytes,uint32)',
        _linkedAdapter,
        abi.encodeWithSignature('receiveAdapterUpgrade(bytes,bytes[])', _l2AdapterBytecode, _l2AdapterInitTxs),
        _minGasLimit
      ),
      abi.encode()
    );

    // Expect events
    vm.expectEmit(true, true, true, true);
    emit L2AdapterUpgradeSent(_l2AdapterImplAddress, _messenger, _minGasLimit);

    // Execute
    vm.prank(_upgradeManager);
    adapter.sendL2AdapterUpgrade(_messenger, _minGasLimit);
  }
}

contract L1OpUSDCBridgeAdapter_Unit_SendL2UsdcUpgrade is Base {
  /**
   * @notice Check that the function reverts if a messenger is unitialized
   */
  function test_revertOnMessagingUnintialized(uint32 _minGasLimit) external {
    // Execute
    vm.prank(_upgradeManager);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_MessagingDisabled.selector);
    adapter.sendL2UsdcUpgrade(_messenger, _minGasLimit);
  }

  /**
   * @notice Check that the message is sent as expected
   */
  function test_expectedCall(uint32 _minGasLimit) external {
    adapter.forTest_setMessagerStatus(_messenger, IL1OpUSDCBridgeAdapter.Status.Active);

    _mockAndExpect(
      address(_messenger),
      abi.encodeWithSignature(
        'sendMessage(address,bytes,uint32)',
        _linkedAdapter,
        abi.encodeWithSignature('receiveUsdcUpgrade(bytes,bytes[])', _l2UsdcBytecode, _l2UsdcInitTxs),
        _minGasLimit
      ),
      abi.encode()
    );

    // Execute
    vm.prank(_upgradeManager);
    adapter.sendL2UsdcUpgrade(_messenger, _minGasLimit);
  }

  /**
   * @notice Check that the event is emitted as expected
   */
  function test_emitEvent(uint32 _minGasLimit) external {
    adapter.forTest_setMessagerStatus(_messenger, IL1OpUSDCBridgeAdapter.Status.Active);

    // Mock calls
    vm.mockCall(
      address(_messenger),
      abi.encodeWithSignature(
        'sendMessage(address,bytes,uint32)',
        _linkedAdapter,
        abi.encodeWithSignature('receiveUsdcUpgrade(bytes,bytes[])', _l2UsdcBytecode, _l2UsdcInitTxs),
        _minGasLimit
      ),
      abi.encode()
    );

    // Expect events
    vm.expectEmit(true, true, true, true);
    emit L2UsdcUpgradeSent(_l2UsdcImplAddress, _messenger, _minGasLimit);

    // Execute
    vm.prank(_upgradeManager);
    adapter.sendL2UsdcUpgrade(_messenger, _minGasLimit);
  }
}

contract L1OpUSDCBridgeAdapter_Unit_UpgradeToAndCall is Base {
  /**
   * @notice Check that the function reverts if the upgrade is not authorized
   */
  function test_revertIfUpgradeNotAuthorized(address _newImplementation) external {
    // Execute
    vm.prank(_user);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidSender.selector);
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
