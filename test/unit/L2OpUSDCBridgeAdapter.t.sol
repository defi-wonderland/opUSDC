pragma solidity ^0.8.25;

import {ERC1967Proxy} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import {L2OpUSDCBridgeAdapter} from 'contracts/L2OpUSDCBridgeAdapter.sol';
import {IL2OpUSDCBridgeAdapter} from 'interfaces/IL2OpUSDCBridgeAdapter.sol';
import {IOpUSDCBridgeAdapter} from 'interfaces/IOpUSDCBridgeAdapter.sol';
import {Helpers} from 'test/utils/Helpers.sol';

contract ForTestL2OpUSDCBridgeAdapter is L2OpUSDCBridgeAdapter {
  /// @notice Number of calls to forTest_dummy
  uint256 public calls;

  constructor(
    address _usdc,
    address _messenger,
    address _linkedAdapter
  ) L2OpUSDCBridgeAdapter(_usdc, _messenger, _linkedAdapter) {}

  function forTest_setIsMessagingDisabled() external {
    isMessagingDisabled = true;
  }

  function forTest_setProxyExecutedInitTxs(uint256 _newLength) external {
    _proxyExecutedInitTxsLength = _newLength;
  }

  function forTest_dummy() external {
    calls++;
  }

  function forTest_proxyExecutedInitTxsLength() external view returns (uint256) {
    return _proxyExecutedInitTxsLength;
  }

  function forTest_authorizeUpgrade(address _newImplementation) external pure {
    _authorizeUpgrade(_newImplementation);
  }

  function forTest_dummyRevert() external pure {
    assembly {
      revert(0, 0)
    }
  }
}

abstract contract Base is Helpers {
  ForTestL2OpUSDCBridgeAdapter public adapter;

  address internal _user = makeAddr('user');
  address internal _signerAd;
  uint256 internal _signerPk;
  address internal _usdc = makeAddr('opUSDC');
  address internal _messenger = makeAddr('messenger');
  address internal _linkedAdapter = makeAddr('linkedAdapter');

  bytes internal _l2AdapterBytecode;
  bytes internal _l2AdapterInitTx = abi.encodeWithSignature('forTest_dummy()');
  bytes[] internal _l2AdapterInitTxs;

  bytes internal _l2UsdcBytecode;
  bytes internal _l2UsdcInitTx = abi.encodeWithSignature('forTest_dummy()');
  bytes[] internal _l2UsdcInitTxs;

  event MessageSent(address _user, address _to, uint256 _amount, address _messenger, uint32 _minGasLimit);
  event MessageReceived(address _user, uint256 _amount, address _messenger);
  event MigratingToNative(address _messenger, address _newOwner);
  event DeployedL2AdapterImplementation(address _adapterImplementation);
  event DeployedL2UsdcImplementation(address _adapterImplementation);

  function setUp() public virtual {
    (_signerAd, _signerPk) = makeAddrAndKey('signer');
    address _implementation = address(new ForTestL2OpUSDCBridgeAdapter(_usdc, _messenger, _linkedAdapter));
    adapter = ForTestL2OpUSDCBridgeAdapter(address(new ERC1967Proxy(_implementation, '')));
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

contract L2OpUSDCBridgeAdapter_Unit_UpgradeToAndCall is Base {
  /**
   * @notice Check that the upgrade is called as expected
   */
  function test_callUpgradeToAndCall(address _newImplementation) external {
    vm.expectRevert(IL2OpUSDCBridgeAdapter.L2OpUSDCBridgeAdapter_DisabledFlow.selector);
    adapter.forTest_authorizeUpgrade(_newImplementation);
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
    emit MessageSent(_user, _to, _amount, _messenger, _minGasLimit);

    // Execute
    vm.prank(_user);
    adapter.sendMessage(_to, _amount, _minGasLimit);
  }
}

contract L2OpUSDCBridgeAdapter_Unit_SendMessageWithSignature is Base {
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
    adapter.forTest_setIsMessagingDisabled();
    // Execute
    vm.prank(_user);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_MessagingDisabled.selector);
    adapter.sendMessage(_signerAd, _to, _amount, _signature, _deadline, _minGasLimit);
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

    // Execute
    vm.prank(_user);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_MessageExpired.selector);
    adapter.sendMessage(_signerAd, _to, _amount, _signature, _deadline, _minGasLimit);
  }

  /**
   * @notice Check that the function reverts on invalid signature
   */
  function test_invalidSignature(address _to, uint256 _amount, uint256 _deadline, uint32 _minGasLimit) external {
    vm.assume(_deadline >= block.timestamp);
    uint256 _nonce = adapter.userNonce(_signerAd);
    (address _notSignerAd, uint256 _notSignerPk) = makeAddrAndKey('notSigner');
    bytes memory _signature = _generateSignature(_to, _amount, _nonce, _notSignerAd, _notSignerPk, address(adapter));

    // Execute
    vm.prank(_user);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidSignature.selector);
    adapter.sendMessage(_signerAd, _to, _amount, _signature, _deadline, _minGasLimit);
  }

  /**
   * @notice Check nonce increment
   */
  function test_nonceIncrement(address _to, uint256 _amount, uint256 _deadline, uint32 _minGasLimit) external {
    vm.assume(_deadline >= block.timestamp);
    uint256 _nonce = adapter.userNonce(_signerAd);
    bytes memory _signature = _generateSignature(_to, _amount, _nonce, _signerAd, _signerPk, address(adapter));
    vm.mockCall(address(_usdc), abi.encodeWithSignature('burn(address,uint256)', _signerAd, _amount), abi.encode(true));
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
    adapter.sendMessage(_signerAd, _to, _amount, _signature, _deadline, _minGasLimit);
    assertEq(adapter.userNonce(_signerAd), _nonce + 1, 'Nonce should be incremented');
  }

  /**
   * @notice Check that burning tokens and sending a message works as expected
   */
  function test_expectedCall(address _to, uint256 _amount, uint256 _deadline, uint32 _minGasLimit) external {
    vm.assume(_deadline >= block.timestamp);
    uint256 _nonce = adapter.userNonce(_signerAd);
    bytes memory _signature = _generateSignature(_to, _amount, _nonce, _signerAd, _signerPk, address(adapter));
    _mockAndExpect(
      address(_usdc), abi.encodeWithSignature('burn(address,uint256)', _signerAd, _amount), abi.encode(true)
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
    adapter.sendMessage(_signerAd, _to, _amount, _signature, _deadline, _minGasLimit);
  }

  /**
   * @notice Check that the event is emitted as expected
   */
  function test_emitEvent(address _to, uint256 _amount, uint256 _deadline, uint32 _minGasLimit) external {
    vm.assume(_deadline >= block.timestamp);
    uint256 _nonce = adapter.userNonce(_signerAd);
    bytes memory _signature = _generateSignature(_to, _amount, _nonce, _signerAd, _signerPk, address(adapter));
    vm.mockCall(address(_usdc), abi.encodeWithSignature('burn(address,uint256)', _signerAd, _amount), abi.encode(true));
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
    adapter.sendMessage(_signerAd, _to, _amount, _signature, _deadline, _minGasLimit);
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
    emit MessageReceived(_user, _amount, _messenger);

    vm.prank(_messenger);
    adapter.receiveMessage(_user, _amount);
  }
}

contract L2OpUSDCBridgeAdapter_Unit_ReceiveStopMessaging is Base {
  event MessagingStopped(address _messenger);

  /**
   * @notice Check that the function reverts if the sender is not the messenger
   */
  function test_wrongMessenger(address _notMessenger) external {
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
  function test_wrongLinkedAdapter() external {
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
  function test_setIsMessagingDisabledToTrue() external {
    _mockAndExpect(_messenger, abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_linkedAdapter));

    // Execute
    vm.prank(_messenger);
    adapter.receiveStopMessaging();
    assertEq(adapter.isMessagingDisabled(), true, 'Messaging should be disabled');
  }

  /**
   * @notice Check that the event is emitted as expected
   */
  function test_emitEvent() external {
    // Mock calls
    vm.mockCall(_messenger, abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_linkedAdapter));

    // Expect events
    vm.expectEmit(true, true, true, true);
    emit MessagingStopped(_messenger);

    // Execute
    vm.prank(_messenger);
    adapter.receiveStopMessaging();
  }
}

contract L2OpUSDCBridgeAdapter_Unit_ReceiveResumeMessaging is Base {
  event MessagingResumed(address _messenger);

  /**
   * @notice Check that the function reverts if the sender is not the messenger
   */
  function test_wrongMessenger(address _notMessenger) external {
    vm.assume(_notMessenger != _messenger);

    // Execute
    vm.prank(_notMessenger);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidSender.selector);
    adapter.receiveResumeMessaging();
  }

  /**
   * @notice Check that the function reverts if the linked adapter didn't send the message
   */
  function test_wrongLinkedAdapter() external {
    address _notLinkedAdapter = makeAddr('notLinkedAdapter');

    _mockAndExpect(_messenger, abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_notLinkedAdapter));

    // Execute
    vm.prank(_messenger);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidSender.selector);
    adapter.receiveResumeMessaging();
  }

  /**
   * @notice Check that isMessagingDisabled is set to false
   */
  function test_setIsMessagingDisabledToFalse() external {
    _mockAndExpect(_messenger, abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_linkedAdapter));

    // Execute
    vm.prank(_messenger);
    adapter.receiveResumeMessaging();
    assertEq(adapter.isMessagingDisabled(), false, 'Messaging should be disabled');
  }

  /**
   * @notice Check that the event is emitted as expected
   */
  function test_emitEvent() external {
    // Mock calls
    vm.mockCall(_messenger, abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_linkedAdapter));

    // Expect events
    vm.expectEmit(true, true, true, true);
    emit MessagingResumed(_messenger);

    // Execute
    vm.prank(_messenger);
    adapter.receiveResumeMessaging();
  }
}

contract L2OpUSDCBridgeAdapter_ReceiveAdapterUpgrade is Base {
  /**
   * @notice Check that the receiveAdapterUpgrade function reverts if the sender is not MESSENGER
   */
  function test_wrongMessenger(address _notMessenger) external {
    vm.assume(_notMessenger != _messenger);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidSender.selector);
    adapter.receiveAdapterUpgrade(_l2AdapterBytecode, _l2AdapterInitTxs);
  }

  /**
   * @notice Check that the receiveAdapterUpgrade function reverts if the sender is not Linked Adapter
   */
  function test_wrongLinkedAdapter(address _notLinkedAdapter) external {
    vm.assume(_notLinkedAdapter != _linkedAdapter);
    // Mock calls
    vm.mockCall(address(_messenger), abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_notLinkedAdapter));

    // Execute
    vm.prank(_messenger);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidSender.selector);
    adapter.receiveAdapterUpgrade(_l2AdapterBytecode, _l2AdapterInitTxs);
  }

  /**
   * @notice Check the expected calls
   */
  function test_receiveAdapterUpgrade(address _newUsdc, address _newMessenger, address _newLinkedAdapter) external {
    vm.assume(_newUsdc != _usdc);
    vm.assume(_newMessenger != _messenger);
    vm.assume(_newLinkedAdapter != _linkedAdapter);

    address _realImplementation = address(new ForTestL2OpUSDCBridgeAdapter(_newUsdc, _newMessenger, _newLinkedAdapter));
    _l2AdapterBytecode = _realImplementation.code;
    _l2AdapterInitTxs.push(_l2AdapterInitTx);

    // Mock calls
    _mockAndExpect(address(_messenger), abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_linkedAdapter));
    // Execute
    vm.prank(_messenger);
    adapter.receiveAdapterUpgrade(_l2AdapterBytecode, _l2AdapterInitTxs);
  }

  /**
   * @notice Check that the immutable variables are set as expected
   */
  function test_setVariables(address _newUsdc, address _newMessenger, address _newLinkedAdapter) external {
    vm.assume(_newUsdc != _usdc);
    vm.assume(_newMessenger != _messenger);
    vm.assume(_newLinkedAdapter != _linkedAdapter);

    address _realImplementation = address(new ForTestL2OpUSDCBridgeAdapter(_newUsdc, _newMessenger, _newLinkedAdapter));
    _l2AdapterBytecode = _realImplementation.code;
    for (uint256 i; i < 5; i++) {
      _l2AdapterInitTxs.push(_l2AdapterInitTx);
    }

    // Mock calls
    vm.mockCall(address(_messenger), abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_linkedAdapter));
    // Execute
    vm.prank(_messenger);
    adapter.receiveAdapterUpgrade(_l2AdapterBytecode, _l2AdapterInitTxs);
    assertEq(adapter.USDC(), _newUsdc, 'USDC should be set to the provided address');
    assertEq(adapter.MESSENGER(), _newMessenger, 'Messenger should be set to the provided address');
    assertEq(adapter.LINKED_ADAPTER(), _newLinkedAdapter, 'Linked adapter should be set to the provided address');
    assertEq(adapter.calls(), 5, 'Calls should be incremented');
  }

  /**
   * @notice Check revert on invalid transaction
   */
  function test_revertOnInitTx(address _newUsdc, address _newMessenger, address _newLinkedAdapter) external {
    vm.assume(_newUsdc != _usdc);
    vm.assume(_newMessenger != _messenger);
    vm.assume(_newLinkedAdapter != _linkedAdapter);

    address _realImplementation = address(new ForTestL2OpUSDCBridgeAdapter(_newUsdc, _newMessenger, _newLinkedAdapter));
    _l2AdapterBytecode = _realImplementation.code;
    _l2AdapterInitTxs.push(abi.encodeWithSignature('forTest_dummyRevert()'));

    // Mock calls
    vm.mockCall(address(_messenger), abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_linkedAdapter));
    // Execute
    vm.prank(_messenger);
    vm.expectRevert(IL2OpUSDCBridgeAdapter.L2OpUSDCBridgeAdapter_AdapterInitializationFailed.selector);
    adapter.receiveAdapterUpgrade(_l2AdapterBytecode, _l2AdapterInitTxs);
  }

  /**
   * @notice Check that the event is emitted as expected
   */
  function test_emitEvent(address _newUsdc, address _newMessenger, address _newLinkedAdapter) external {
    vm.assume(_newUsdc != _usdc);
    vm.assume(_newMessenger != _messenger);
    vm.assume(_newLinkedAdapter != _linkedAdapter);
    uint64 _nonce = vm.getNonce(address(adapter));

    address _realImplementation = address(new ForTestL2OpUSDCBridgeAdapter(_newUsdc, _newMessenger, _newLinkedAdapter));
    _l2AdapterBytecode = _realImplementation.code;
    _l2AdapterInitTxs.push(_l2AdapterInitTx);

    // Mock calls
    vm.mockCall(address(_messenger), abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_linkedAdapter));
    // Expect events
    vm.expectEmit(true, true, true, true);
    emit DeployedL2AdapterImplementation(_computeCreateAddress(address(adapter), _nonce));

    // Execute
    vm.prank(_messenger);
    adapter.receiveAdapterUpgrade(_l2AdapterBytecode, _l2AdapterInitTxs);
  }
}

contract L2OpUSDCBridgeAdapter_ReceiveUsdcUpgrade is Base {
  /**
   * @notice Check that the receiveUsdcUpgrade function reverts if the sender is not MESSENGER
   */
  function test_wrongMessenger(address _notMessenger) external {
    vm.assume(_notMessenger != _messenger);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidSender.selector);
    adapter.receiveUsdcUpgrade(_l2UsdcBytecode, _l2UsdcInitTxs);
  }

  /**
   * @notice Check that the receiveUsdcUpgrade function reverts if the sender is not Linked Adapter
   */
  function test_wrongLinkedAdapter(address _notLinkedAdapter) external {
    vm.assume(_notLinkedAdapter != _linkedAdapter);
    // Mock calls
    vm.mockCall(_messenger, abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_notLinkedAdapter));

    // Execute
    vm.prank(_messenger);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidSender.selector);
    adapter.receiveUsdcUpgrade(_l2UsdcBytecode, _l2UsdcInitTxs);
  }

  /**
   * @notice Check the expected calls
   */
  function test_receiveUsdcUpgrade() external {
    uint64 _nonce = vm.getNonce(address(adapter));
    address _implementation = _computeCreateAddress(address(adapter), _nonce);
    _l2UsdcInitTxs.push(abi.encodeWithSignature('dummy()'));

    // Mock calls
    _mockAndExpect(_messenger, abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_linkedAdapter));
    _mockAndExpect(_usdc, abi.encodeWithSignature('upgradeTo(address)', _implementation), abi.encode(true));

    _mockAndExpect(_usdc, abi.encodeWithSignature('dummy()'), abi.encode(true));
    // Execute
    vm.prank(_messenger);
    adapter.receiveUsdcUpgrade(_l2UsdcBytecode, _l2UsdcInitTxs);
  }

  /**
   * @notice Check the expected calls
   */
  function test_receiveUsdcUpgradeMultipleInitTxs() external {
    adapter.forTest_setProxyExecutedInitTxs(2);
    uint64 _nonce = vm.getNonce(address(adapter));
    address _implementation = _computeCreateAddress(address(adapter), _nonce);
    _l2UsdcInitTxs.push(abi.encodeWithSignature('dummy()'));
    _l2UsdcInitTxs.push(abi.encodeWithSignature('dummyTwo()'));
    _l2UsdcInitTxs.push(abi.encodeWithSignature('dummyThree()'));
    _l2UsdcInitTxs.push(abi.encodeWithSignature('dummyFour()'));

    // Mock calls
    _mockAndExpect(_messenger, abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_linkedAdapter));
    _mockAndExpect(_usdc, abi.encodeWithSignature('upgradeTo(address)', _implementation), abi.encode(true));

    _mockAndExpect(_usdc, abi.encodeWithSignature('dummyThree()'), abi.encode(true));
    // Execute
    vm.prank(_messenger);
    adapter.receiveUsdcUpgrade(_l2UsdcBytecode, _l2UsdcInitTxs);
  }

  /**
   * @notice Check the expected calls on a second upgrade
   */
  function test_receive2ndUsdcUpgrade() external {
    adapter.forTest_setProxyExecutedInitTxs(1);
    uint64 _nonce = vm.getNonce(address(adapter));
    _l2UsdcInitTxs.push(abi.encodeWithSignature('dummy()'));
    // Mock calls
    _mockAndExpect(_messenger, abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_linkedAdapter));
    _mockAndExpect(
      _usdc,
      abi.encodeWithSignature('upgradeTo(address)', _computeCreateAddress(address(adapter), _nonce)),
      abi.encode(true)
    );
    // Execute
    vm.prank(_messenger);
    adapter.receiveUsdcUpgrade(_l2UsdcBytecode, _l2UsdcInitTxs);
  }

  /**
   * @notice Check that reverts if a call to implementation reverts
   */
  function test_revertOnImplementation() external {
    adapter.forTest_setProxyExecutedInitTxs(1);
    uint64 _nonce = vm.getNonce(address(adapter));
    _l2UsdcInitTxs.push(abi.encodeWithSignature('dummyRevert()'));
    // Mock calls
    _mockAndExpect(_messenger, abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_linkedAdapter));
    _mockAndExpect(
      _usdc,
      abi.encodeWithSignature('upgradeTo(address)', _computeCreateAddress(address(adapter), _nonce)),
      abi.encode(true)
    );
    // Execute
    vm.prank(_messenger);
    adapter.receiveUsdcUpgrade(_l2UsdcBytecode, _l2UsdcInitTxs);
  }

  /**
   * @notice Revert on invalid transaction
   */
  function test_revertOnInitTx() external {
    uint64 _nonce = vm.getNonce(address(adapter));
    _l2UsdcInitTxs.push(abi.encodeWithSignature('dummyRevert()'));

    // Mock calls
    _mockAndExpect(_messenger, abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_linkedAdapter));
    _mockAndExpect(
      _usdc,
      abi.encodeWithSignature('upgradeTo(address)', _computeCreateAddress(address(adapter), _nonce)),
      abi.encode(true)
    );

    // Mock Revert
    vm.mockCallRevert(_usdc, abi.encodeWithSignature('dummyRevert()'), abi.encode(''));

    // Execute
    vm.prank(_messenger);
    vm.expectRevert(IL2OpUSDCBridgeAdapter.L2OpUSDCBridgeAdapter_UsdcInitializationFailed.selector);
    adapter.receiveUsdcUpgrade(_l2UsdcBytecode, _l2UsdcInitTxs);
  }

  /**
   * @notice Check that the event is emitted as expected
   */
  function test_emitEvent() external {
    uint64 _nonce = vm.getNonce(address(adapter));
    // Mock calls
    vm.mockCall(_messenger, abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_linkedAdapter));
    vm.mockCall(
      _usdc,
      abi.encodeWithSignature('upgradeTo(address)', _computeCreateAddress(address(adapter), _nonce)),
      abi.encode(true)
    );

    // Expect events
    vm.expectEmit(true, true, true, true);
    emit DeployedL2UsdcImplementation(_computeCreateAddress(address(adapter), _nonce));

    // Execute
    vm.prank(_messenger);
    adapter.receiveUsdcUpgrade(_l2UsdcBytecode, _l2UsdcInitTxs);
  }
}

contract L2OpUSDCBridgeAdapter_setProxyExecutedInitTxs is Base {
  /**
   * @notice Check that _proxyExecutedInitTxsLength  can not be set if is not 0
   */
  function test_revertIfLengthIsNotZero() external {
    adapter.forTest_setProxyExecutedInitTxs(4);
    vm.expectRevert(IL2OpUSDCBridgeAdapter.L2OpUSDCBridgeAdapter_InitializationAlreadyExecuted.selector);
    adapter.setProxyExecutedInitTxs(1);
  }

  /**
   * @notice Check that _proxyExecutedInitTxsLength  can be set if is 0
   */
  function test_setProxyExecutedInitTxs() external {
    adapter.setProxyExecutedInitTxs(1);
    assertEq(adapter.forTest_proxyExecutedInitTxsLength(), 1, 'Last L2 Usdc Init Txs Length should be set to 1');
  }
}

contract L2OpUSDCBridgeAdapter_AuthorizeUpgrade is Base {
  /**
   * @notice Check that the upgrade is authorized as expected
   */
  function test_authorizeUpgrade(address _newImplementation) external {
    vm.expectRevert(IL2OpUSDCBridgeAdapter.L2OpUSDCBridgeAdapter_DisabledFlow.selector);
    adapter.forTest_authorizeUpgrade(_newImplementation);
  }
}

contract L2OpUSDCBridgeAdapter_Unit_ReceiveMigrateToNative is Base {
  /**
   * @notice Check that the upgradeToAndCall function reverts if the sender is not MESSENGER
   */
  function test_revertIfNotMessenger(address _newOwner, uint32 _setBurnAmountMinGasLimit) external {
    // Execute
    vm.prank(_user);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidSender.selector);
    adapter.receiveMigrateToNative(_newOwner, _setBurnAmountMinGasLimit);
  }

  /**
   * @notice Check that the upgradeToAndCall function reverts if the sender is not Linked Adapter
   */
  function test_revertIfNotLinkedAdapter(address _newOwner, uint32 _setBurnAmountMinGasLimit) external {
    // Mock calls
    vm.mockCall(address(_messenger), abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_user));

    // Execute
    vm.prank(_messenger);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidSender.selector);
    adapter.receiveMigrateToNative(_newOwner, _setBurnAmountMinGasLimit);
  }

  /**
   * @notice Check that the upgrade is called as expected
   */
  function test_expectCall(address _newOwner, uint32 _setBurnAmountMinGasLimit, uint256 _burnAmount) external {
    // Mock calls
    vm.mockCall(address(_messenger), abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_linkedAdapter));

    _mockAndExpect(address(_usdc), abi.encodeWithSignature('transferOwnership(address)', _newOwner), abi.encode());
    _mockAndExpect(address(_usdc), abi.encodeWithSignature('totalSupply()'), abi.encode(_burnAmount));
    _mockAndExpect(
      address(_messenger),
      abi.encodeWithSignature(
        'sendMessage(address,bytes,uint32)',
        _linkedAdapter,
        abi.encodeWithSignature('setBurnAmount(uint256)', _burnAmount),
        _setBurnAmountMinGasLimit
      ),
      abi.encode()
    );

    // Execute
    vm.prank(_messenger);
    adapter.receiveMigrateToNative(_newOwner, _setBurnAmountMinGasLimit);
  }

  function test_stateChange(address _newOwner, uint32 _setBurnAmountMinGasLimit) external {
    // Mock calls
    vm.mockCall(address(_messenger), abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_linkedAdapter));

    _mockAndExpect(address(_usdc), abi.encodeWithSignature('transferOwnership(address)', _newOwner), abi.encode());
    _mockAndExpect(address(_usdc), abi.encodeWithSignature('totalSupply()'), abi.encode(100));
    _mockAndExpect(
      address(_messenger),
      abi.encodeWithSignature(
        'sendMessage(address,bytes,uint32)',
        _linkedAdapter,
        abi.encodeWithSignature('setBurnAmount(uint256)', 100),
        _setBurnAmountMinGasLimit
      ),
      abi.encode()
    );

    // Execute
    vm.prank(_messenger);
    adapter.receiveMigrateToNative(_newOwner, _setBurnAmountMinGasLimit);
    assertEq(adapter.isMessagingDisabled(), true, 'Messaging should be disabled');
  }

  /**
   * @notice Check that the event is emitted as expected
   */
  function test_emitEvent(address _newOwner, uint32 _setBurnAmountMinGasLimit, uint256 _burnAmount) external {
    // Mock calls
    vm.mockCall(address(_messenger), abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_linkedAdapter));
    vm.mockCall(address(_usdc), abi.encodeWithSignature('transferOwnership(address)', _newOwner), abi.encode());
    vm.mockCall(address(_usdc), abi.encodeWithSignature('totalSupply()'), abi.encode(_burnAmount));
    vm.mockCall(
      address(_messenger),
      abi.encodeWithSignature(
        'sendMessage(address,bytes,uint32)',
        _linkedAdapter,
        abi.encodeWithSignature('setBurnAmount(uint256)', _burnAmount),
        _setBurnAmountMinGasLimit
      ),
      abi.encode()
    );

    // Expect events
    vm.expectEmit(true, true, true, true);
    emit MigratingToNative(_messenger, _newOwner);

    // Execute
    vm.prank(_messenger);
    adapter.receiveMigrateToNative(_newOwner, _setBurnAmountMinGasLimit);
  }
}
