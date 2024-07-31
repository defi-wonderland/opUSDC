pragma solidity ^0.8.25;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {ERC1967Proxy} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import {L2OpUSDCBridgeAdapter} from 'contracts/L2OpUSDCBridgeAdapter.sol';
import {IOpUSDCBridgeAdapter} from 'interfaces/IOpUSDCBridgeAdapter.sol';
import {OpUSDCBridgeAdapter} from 'src/contracts/universal/OpUSDCBridgeAdapter.sol';
import {Helpers} from 'test/utils/Helpers.sol';

contract ForTestL2OpUSDCBridgeAdapter is L2OpUSDCBridgeAdapter {
  /// @notice Number of calls to forTest_dummy
  uint256 public calls;

  constructor(
    address _usdc,
    address _messenger,
    address _linkedAdapter
  ) L2OpUSDCBridgeAdapter(_usdc, _messenger, _linkedAdapter) {}

  function forTest_setMessengerStatus(Status _status) external {
    messengerStatus = _status;
  }

  function forTest_setRoleCaller(address _roleCaller) external {
    roleCaller = _roleCaller;
  }

  function forTest_setUserNonce(address _user, uint256 _nonce, bool _used) external {
    userNonces[_user][_nonce] = _used;
  }

  function forTest_setUserBlacklistedFunds(address _spender, address _user, uint256 _amount) external {
    blacklistedFundsDetails[_spender][_user] = _amount;
  }
}

abstract contract Base is Helpers {
  string internal constant _NAME = 'L1OpUSDCBridgeAdapter';
  string internal constant _VERSION = '1.0.0';
  bytes4 internal constant _UPGRADE_TO_SELECTOR = 0x3659cfe6;
  bytes4 internal constant _UPGRADE_TO_AND_CALL_SELECTOR = 0x4f1ef286;

  ForTestL2OpUSDCBridgeAdapter public adapter;

  address internal _user = makeAddr('user');
  address internal _owner = makeAddr('owner');
  address internal _usdc = makeAddr('opUSDC');
  address internal _messenger = makeAddr('messenger');
  address internal _linkedAdapter = makeAddr('linkedAdapter');
  address internal _adapterImpl;
  address internal _signerAd;
  uint256 internal _signerPk;

  event MigratingToNative(address _messenger, address _roleCaller);
  event MessageSent(
    address indexed _user, address indexed _to, uint256 _amount, address indexed _messenger, uint32 _minGasLimit
  );
  event MessageReceived(address indexed _spender, address indexed _user, uint256 _amount, address indexed _messenger);
  event USDCFunctionSent(bytes4 _functionSignature);

  function setUp() public virtual {
    (_signerAd, _signerPk) = makeAddrAndKey('signer');

    _adapterImpl = address(new ForTestL2OpUSDCBridgeAdapter(_usdc, _messenger, _linkedAdapter));
    adapter = ForTestL2OpUSDCBridgeAdapter(
      address(new ERC1967Proxy(_adapterImpl, abi.encodeCall(OpUSDCBridgeAdapter.initialize, _owner)))
    );
  }
}

contract L2OpUSDCBridgeAdapter_Unit_Constructor is Base {
  /**
   * @notice Check that the constructor works as expected
   */
  function test_immutables() public view {
    assertEq(adapter.USDC(), _usdc, 'USDC should be set to the provided address');
    assertEq(adapter.MESSENGER(), _messenger, 'Messenger should be set to the provided address');
    assertEq(adapter.LINKED_ADAPTER(), _linkedAdapter, 'Linked adapter should be set to the provided address');
    assertEq(adapter.owner(), _owner, 'Owner should be set to the provided address');
    assertGt(address(adapter.FALLBACK_PROXY_ADMIN()).code.length, 0, 'Fallback proxy admin was not deployed');
  }
}

/*///////////////////////////////////////////////////////////////
                              MIGRATION
  ///////////////////////////////////////////////////////////////*/
contract L2OpUSDCBridgeAdapter_Unit_ReceiveMigrateToNative is Base {
  /**
   * @notice Check that the upgradeToAndCall function reverts if the sender is not MESSENGER
   */
  function test_revertIfNotMessenger(address _roleCaller, uint32 _setBurnAmountMinGasLimit) external {
    // Execute
    vm.prank(_user);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidSender.selector);
    adapter.receiveMigrateToNative(_roleCaller, _setBurnAmountMinGasLimit);
  }

  /**
   * @notice Check that the upgradeToAndCall function reverts if the sender is not Linked Adapter
   */
  function test_revertIfNotLinkedAdapter(address _roleCaller, uint32 _setBurnAmountMinGasLimit) external {
    // Mock calls
    vm.mockCall(_messenger, abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_user));

    // Execute
    vm.prank(_messenger);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidSender.selector);
    adapter.receiveMigrateToNative(_roleCaller, _setBurnAmountMinGasLimit);
  }

  /**
   * @notice Check that the upgrade is called as expected
   */
  function test_expectCall(address _roleCaller, uint32 _setBurnAmountMinGasLimit, uint256 _burnAmount) external {
    // Mock calls
    vm.mockCall(_messenger, abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_linkedAdapter));

    _mockAndExpect(_usdc, abi.encodeWithSignature('totalSupply()'), abi.encode(_burnAmount));
    _mockAndExpect(_usdc, abi.encodeWithSignature('removeMinter(address)', adapter), abi.encode(true));
    _mockAndExpect(
      _messenger,
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
    adapter.receiveMigrateToNative(_roleCaller, _setBurnAmountMinGasLimit);
  }

  function test_stateChange(address _roleCaller, uint32 _setBurnAmountMinGasLimit) external {
    // Mock calls
    vm.mockCall(_messenger, abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_linkedAdapter));

    _mockAndExpect(_usdc, abi.encodeWithSignature('totalSupply()'), abi.encode(100));
    _mockAndExpect(_usdc, abi.encodeWithSignature('removeMinter(address)', adapter), abi.encode(true));
    _mockAndExpect(
      _messenger,
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
    adapter.receiveMigrateToNative(_roleCaller, _setBurnAmountMinGasLimit);
    assertEq(
      uint256(adapter.messengerStatus()),
      uint256(IOpUSDCBridgeAdapter.Status.Deprecated),
      'Messaging should be disabled'
    );
    assertEq(adapter.roleCaller(), _roleCaller, 'Role caller should be set to the new owner');
  }

  /**
   * @notice Check that the event is emitted as expected
   */
  function test_emitEvent(address _roleCaller, uint32 _setBurnAmountMinGasLimit, uint256 _burnAmount) external {
    // Mock calls
    vm.mockCall(_messenger, abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_linkedAdapter));
    vm.mockCall(_usdc, abi.encodeWithSignature('transferOwnership(address)', _roleCaller), abi.encode());
    vm.mockCall(_usdc, abi.encodeWithSignature('changeAdmin(address)', _roleCaller), abi.encode());
    vm.mockCall(_usdc, abi.encodeWithSignature('totalSupply()'), abi.encode(_burnAmount));
    vm.mockCall(_usdc, abi.encodeWithSignature('removeMinter(address)', adapter), abi.encode(true));
    vm.mockCall(
      _messenger,
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
    emit MigratingToNative(_messenger, _roleCaller);

    // Execute
    vm.prank(_messenger);
    adapter.receiveMigrateToNative(_roleCaller, _setBurnAmountMinGasLimit);
  }
}

contract L2OpUSDCBridgeAdapter_Unit_TransferUSDCRoles is Base {
  /**
   * @notice Check that the function reverts if the sender is not the roleCaller
   */
  function test_revertIfNotRoleCaller(address _notRoleCaller) external {
    vm.assume(_notRoleCaller != adapter.roleCaller());

    // Execute
    vm.prank(_notRoleCaller);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidCaller.selector);
    adapter.transferUSDCRoles(_owner);
  }

  /**
   * @notice Check that the function transfers the roles
   */
  function test_expectedCall(address _roleCaller) external {
    adapter.forTest_setRoleCaller(_roleCaller);

    // Mock calls
    _mockAndExpect(_usdc, abi.encodeWithSignature('transferOwnership(address)', _roleCaller), abi.encode());
    _mockAndExpect(_usdc, abi.encodeWithSignature('changeAdmin(address)', _roleCaller), abi.encode());

    // Execute
    vm.prank(_roleCaller);
    adapter.transferUSDCRoles(_roleCaller);
  }
}

/*///////////////////////////////////////////////////////////////
                          MESSAGING CONTROL
  ///////////////////////////////////////////////////////////////*/
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
    assertEq(
      uint256(adapter.messengerStatus()),
      uint256(IOpUSDCBridgeAdapter.Status.Active),
      'Messaging should not be disabled'
    );
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
    assertEq(
      uint256(adapter.messengerStatus()),
      uint256(IOpUSDCBridgeAdapter.Status.Active),
      'Messaging should not be disabled'
    );
  }

  /**
   * @notice Check that function reverts if status is Deprecated
   */
  function test_revertIfDeprecated() external {
    adapter.forTest_setMessengerStatus(IOpUSDCBridgeAdapter.Status.Deprecated);

    _mockAndExpect(_messenger, abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_linkedAdapter));

    // Execute
    vm.prank(_messenger);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_MessagingDisabled.selector);
    adapter.receiveStopMessaging();
  }

  /**
   * @notice Check that isMessagingDisabled is set to true
   */
  function test_setIsMessagingDisabledToTrue() external {
    _mockAndExpect(_messenger, abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_linkedAdapter));

    // Execute
    vm.prank(_messenger);
    adapter.receiveStopMessaging();
    assertEq(
      uint256(adapter.messengerStatus()), uint256(IOpUSDCBridgeAdapter.Status.Paused), 'Messaging should be disabled'
    );
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
   * @notice Check that function reverts if status is Deprecated
   */
  function test_revertIfDeprecated() external {
    adapter.forTest_setMessengerStatus(IOpUSDCBridgeAdapter.Status.Deprecated);

    _mockAndExpect(_messenger, abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_linkedAdapter));

    // Execute
    vm.prank(_messenger);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_MessagingDisabled.selector);
    adapter.receiveResumeMessaging();
  }

  /**
   * @notice Check that messaging is enabled
   */
  function test_setMessengerStatusToActive() external {
    _mockAndExpect(_messenger, abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_linkedAdapter));

    // Execute
    vm.prank(_messenger);
    adapter.receiveResumeMessaging();
    assertEq(
      uint256(adapter.messengerStatus()), uint256(IOpUSDCBridgeAdapter.Status.Active), 'Messaging should be enabled'
    );
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

/*///////////////////////////////////////////////////////////////
                             MESSAGING
  ///////////////////////////////////////////////////////////////*/

contract L2OpUSDCBridgeAdapter_Unit_SendMessage is Base {
  /**
   * @notice Check that the function reverts if the address is zero
   */
  function test_revertOnZeroAddress(uint256 _amount, uint32 _minGasLimit) external {
    // Execute
    vm.prank(_user);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidAddress.selector);
    adapter.sendMessage(address(0), _amount, _minGasLimit);
  }

  /**
   * @notice Check that the function reverts if the address is blacklisted
   */
  function test_revertOnBlacklistedAddress(address _to, uint256 _amount, uint32 _minGasLimit) external {
    vm.assume(_to != address(0));
    vm.mockCall(_usdc, abi.encodeWithSignature('isBlacklisted(address)', _to), abi.encode(true));
    // Execute
    vm.prank(_user);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_BlacklistedAddress.selector);
    adapter.sendMessage(_to, _amount, _minGasLimit);
  }

  /**
   * @notice Check that sending a message reverts if messaging is disabled
   */
  function test_revertOnMessagingPaused(address _to, uint256 _amount, uint32 _minGasLimit) external {
    vm.assume(_to != address(0));
    adapter.forTest_setMessengerStatus(IOpUSDCBridgeAdapter.Status.Paused);
    vm.mockCall(_usdc, abi.encodeWithSignature('isBlacklisted(address)', _to), abi.encode(false));
    // Execute
    vm.prank(_user);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_MessagingDisabled.selector);
    adapter.sendMessage(_to, _amount, _minGasLimit);
  }

  /**
   * @notice Check that the function reverts if the nonce is already used
   */
  function test_revertOnUsedNonce(
    address _to,
    uint256 _amount,
    bytes memory _signature,
    uint256 _nonce,
    uint256 _deadline,
    uint32 _minGasLimit
  ) external {
    vm.assume(_to != address(0));
    vm.mockCall(_usdc, abi.encodeWithSignature('isBlacklisted(address)', _to), abi.encode(false));
    adapter.forTest_setUserNonce(_signerAd, _nonce, true);

    // Execute
    vm.prank(_user);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidNonce.selector);
    adapter.sendMessage(_signerAd, _to, _amount, _signature, _nonce, _deadline, _minGasLimit);
  }

  /**
   * @notice Check that burning tokens and sending a message works as expected
   */
  function test_expectedCall(address _to, uint256 _amount, uint32 _minGasLimit) external {
    vm.assume(_to != address(0));
    _mockAndExpect(
      _usdc,
      abi.encodeWithSignature('transferFrom(address,address,uint256)', _user, address(adapter), _amount),
      abi.encode(true)
    );
    _mockAndExpect(_usdc, abi.encodeWithSignature('isBlacklisted(address)', _to), abi.encode(false));
    _mockAndExpect(_usdc, abi.encodeWithSignature('burn(uint256)', _amount), abi.encode(true));
    _mockAndExpect(
      _messenger,
      abi.encodeWithSignature(
        'sendMessage(address,bytes,uint32)',
        _linkedAdapter,
        abi.encodeWithSignature('receiveMessage(address,address,uint256)', _to, _user, _amount),
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
    vm.assume(_to != address(0));
    // Mock calls
    vm.mockCall(_usdc, abi.encodeWithSignature('burn(address,uint256)', _user, _amount), abi.encode(true));
    vm.mockCall(_usdc, abi.encodeWithSignature('isBlacklisted(address)', _to), abi.encode(false));
    vm.mockCall(
      _messenger,
      abi.encodeWithSignature(
        'sendMessage(address,bytes,uint32)',
        _linkedAdapter,
        abi.encodeWithSignature('receiveMessage(address,address,uint256)', _to, _amount),
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
   * @notice Check that the function reverts if the address is zero
   */
  function test_revertOnZeroAddress(
    uint256 _amount,
    uint32 _minGasLimit,
    bytes memory _signature,
    uint256 _nonce,
    uint256 _deadline
  ) external {
    // Execute
    vm.prank(_user);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidAddress.selector);
    adapter.sendMessage(_signerAd, address(0), _amount, _signature, _nonce, _deadline, _minGasLimit);
  }

  /**
   * @notice Check that the function reverts if the address is blacklisted
   */
  function test_revertOnBlacklistedAddress(
    address _to,
    uint256 _amount,
    bytes memory _signature,
    uint256 _nonce,
    uint256 _deadline,
    uint32 _minGasLimit
  ) external {
    vm.assume(_to != address(0));
    vm.mockCall(_usdc, abi.encodeWithSignature('isBlacklisted(address)', _to), abi.encode(true));
    // Execute
    vm.prank(_user);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_BlacklistedAddress.selector);
    adapter.sendMessage(_signerAd, _to, _amount, _signature, _nonce, _deadline, _minGasLimit);
  }
  /**
   * @notice Check that the function reverts if messaging is disabled
   */

  function test_revertOnMessengerNotActive(
    address _to,
    uint256 _amount,
    bytes memory _signature,
    uint256 _nonce,
    uint256 _deadline,
    uint32 _minGasLimit
  ) external {
    vm.assume(_to != address(0));
    adapter.forTest_setMessengerStatus(IOpUSDCBridgeAdapter.Status.Paused);

    vm.mockCall(_usdc, abi.encodeWithSignature('isBlacklisted(address)', _to), abi.encode(false));

    // Execute
    vm.prank(_user);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_MessagingDisabled.selector);
    adapter.sendMessage(_signerAd, _to, _amount, _signature, _nonce, _deadline, _minGasLimit);
  }

  /**
   * @notice Check that the function reverts if the deadline is in the past
   */
  function test_revertOnExpiredMessage(
    address _to,
    uint256 _amount,
    bytes memory _signature,
    uint256 _nonce,
    uint256 _timestamp,
    uint256 _deadline,
    uint32 _minGasLimit
  ) external {
    vm.assume(_to != address(0));
    vm.assume(_timestamp > _deadline);
    vm.warp(_timestamp);
    vm.mockCall(_usdc, abi.encodeWithSignature('isBlacklisted(address)', _to), abi.encode(false));
    // Execute
    vm.prank(_user);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_MessageExpired.selector);
    adapter.sendMessage(_signerAd, _to, _amount, _signature, _nonce, _deadline, _minGasLimit);
  }

  /**
   * @notice Check that the function reverts on invalid signature
   */
  function test_invalidSignature(
    address _to,
    uint256 _amount,
    uint256 _nonce,
    uint256 _deadline,
    uint32 _minGasLimit
  ) external {
    vm.assume(_to != address(0));
    vm.assume(_deadline > 0);
    vm.warp(_deadline - 1);
    (address _notSignerAd, uint256 _notSignerPk) = makeAddrAndKey('notSigner');
    bytes memory _signature = _generateSignature(
      _NAME, _VERSION, _to, _amount, _deadline, _minGasLimit, _nonce, _notSignerAd, _notSignerPk, address(adapter)
    );
    vm.mockCall(_usdc, abi.encodeWithSignature('isBlacklisted(address)', _to), abi.encode(false));
    // Execute
    vm.prank(_user);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidSignature.selector);
    adapter.sendMessage(_signerAd, _to, _amount, _signature, _nonce, _deadline, _minGasLimit);
  }

  /**
   * @notice Check that burning tokens and sending a message works as expected
   */
  function test_expectedCall(
    address _to,
    uint256 _amount,
    uint256 _nonce,
    uint256 _deadline,
    uint32 _minGasLimit
  ) external {
    vm.assume(_to != address(0));
    vm.assume(_deadline > 0);
    vm.warp(_deadline - 1);
    bytes memory _signature = _generateSignature(
      _NAME, _VERSION, _to, _amount, _deadline, _minGasLimit, _nonce, _signerAd, _signerPk, address(adapter)
    );

    _mockAndExpect(_usdc, abi.encodeWithSignature('isBlacklisted(address)', _to), abi.encode(false));
    _mockAndExpect(
      _usdc,
      abi.encodeWithSignature('transferFrom(address,address,uint256)', _signerAd, address(adapter), _amount),
      abi.encode(true)
    );
    _mockAndExpect(_usdc, abi.encodeWithSignature('burn(uint256)', _amount), abi.encode(true));
    _mockAndExpect(
      _messenger,
      abi.encodeWithSignature(
        'sendMessage(address,bytes,uint32)',
        _linkedAdapter,
        abi.encodeWithSignature('receiveMessage(address,address,uint256)', _to, _signerAd, _amount),
        _minGasLimit
      ),
      abi.encode()
    );

    // Execute
    vm.prank(_user);
    adapter.sendMessage(_signerAd, _to, _amount, _signature, _nonce, _deadline, _minGasLimit);
  }

  /**
   * @notice Check that the event is emitted as expected
   */
  function test_emitEvent(
    address _to,
    uint256 _amount,
    uint256 _nonce,
    uint256 _deadline,
    uint32 _minGasLimit
  ) external {
    vm.assume(_to != address(0));
    vm.assume(_deadline > 0);
    vm.warp(_deadline - 1);
    bytes memory _signature = _generateSignature(
      _NAME, _VERSION, _to, _amount, _deadline, _minGasLimit, _nonce, _signerAd, _signerPk, address(adapter)
    );

    vm.mockCall(_usdc, abi.encodeWithSignature('isBlacklisted(address)', _to), abi.encode(false));
    vm.mockCall(
      _usdc,
      abi.encodeWithSignature('transferFrom(address,address,uint256)', _user, address(adapter), _amount),
      abi.encode(true)
    );
    vm.mockCall(_usdc, abi.encodeWithSignature('burn(uint256)', _amount), abi.encode(true));
    vm.mockCall(
      _messenger,
      abi.encodeWithSignature(
        'sendMessage(address,bytes,uint32)',
        _linkedAdapter,
        abi.encodeWithSignature('receiveMessage(address,address,uint256)', _to, _amount),
        _minGasLimit
      ),
      abi.encode()
    );

    // Expect events
    vm.expectEmit(true, true, true, true);
    emit MessageSent(_signerAd, _to, _amount, _messenger, _minGasLimit);

    // Execute
    vm.prank(_user);
    adapter.sendMessage(_signerAd, _to, _amount, _signature, _nonce, _deadline, _minGasLimit);
  }
}

contract L2OpUSDCBridgeAdapter_Unit_ReceiveMessage is Base {
  event ReplayedFundsSentBackToL1(address _spender, uint256 _amount);

  event MessageFailed(address indexed _spender, address indexed _user, uint256 _amount, address _messenger);

  /**
   * @notice Check that the function reverts if the sender is not the messenger
   */
  function test_revertIfNotMessenger(uint256 _amount) external {
    // Execute
    vm.prank(_user);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidSender.selector);
    adapter.receiveMessage(_user, _user, _amount);
  }

  /**
   * @notice Check that the function reverts if the linked adapter didn't send the message
   */
  function test_revertIfLinkedAdapterDidntSendTheMessage(uint256 _amount, address _messageSender) external {
    vm.assume(_linkedAdapter != _messageSender);

    // Mock calls
    vm.mockCall(_messenger, abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_messageSender));

    // Execute
    vm.prank(_messenger);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidSender.selector);
    adapter.receiveMessage(_user, _user, _amount);
  }

  /**
   * @notice Check that the function returns the funds if the contract is deprecated
   */
  function test_refundSpenderAfterMigration(uint256 _amount) external {
    adapter.forTest_setMessengerStatus(IOpUSDCBridgeAdapter.Status.Deprecated);
    // Mock calls
    vm.mockCall(_messenger, abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_linkedAdapter));

    // Expected call
    _mockAndExpect(
      _messenger,
      abi.encodeWithSignature(
        'sendMessage(address,bytes,uint32)',
        _linkedAdapter,
        abi.encodeWithSignature('receiveMessage(address,address,uint256)', _user, _user, _amount),
        150_000
      ),
      abi.encode()
    );
    // Execute
    vm.prank(_messenger);
    adapter.receiveMessage(_user, _user, _amount);
  }

  /**
   * @notice Check that the function emits the event as expected
   */
  function test_emitReplayedEvent(address _spender, uint256 _amount) external {
    adapter.forTest_setMessengerStatus(IOpUSDCBridgeAdapter.Status.Deprecated);
    // Mock calls
    vm.mockCall(_messenger, abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_linkedAdapter));

    // Expect event to be emitted
    vm.expectEmit(true, true, true, true);
    emit ReplayedFundsSentBackToL1(_spender, _amount);

    // Execute
    vm.prank(_messenger);
    adapter.receiveMessage(_user, _spender, _amount);
  }

  /**
   * @notice Check that the token minting works as expected
   */
  function test_mintTokens(uint256 _amount) external {
    // Mock calls
    vm.mockCall(_messenger, abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_linkedAdapter));

    _mockAndExpect(_usdc, abi.encodeWithSignature('mint(address,uint256)', _user, _amount), abi.encode(true));

    // Execute
    vm.prank(_messenger);
    adapter.receiveMessage(_user, _user, _amount);
  }

  /**
   * @notice Check that the event is emitted as expected
   */
  function test_emitEvent(uint256 _amount) external {
    // Mock calls
    vm.mockCall(_messenger, abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_linkedAdapter));

    vm.mockCall(_usdc, abi.encodeWithSignature('mint(address,uint256)', _user, _amount), abi.encode(true));

    // Execute
    vm.expectEmit(true, true, true, true);
    emit MessageReceived(_user, _user, _amount, _messenger);

    vm.prank(_messenger);
    adapter.receiveMessage(_user, _user, _amount);
  }

  /**
   * @notice Check that blacklisted funds are updated as expected
   */
  function test_updateBlacklistedFunds(uint256 _amount) external {
    vm.assume(_amount > 0);
    vm.mockCall(_messenger, abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_linkedAdapter));

    // Need to mock call, then mock the revert (foundry bug?)

    vm.mockCall(_usdc, abi.encodeWithSignature('mint(address,uint256)', _user, _amount), abi.encode(true));
    vm.mockCallRevert(_usdc, abi.encodeWithSignature('mint(address,uint256)', _user, _amount), abi.encode(false));
    // Execute
    vm.prank(_messenger);
    adapter.receiveMessage(_user, _user, _amount);

    assertEq(adapter.blacklistedFundsDetails(_user, _user), _amount, 'Blacklisted funds should be set to the amount');
  }

  /**
   * @notice Check that the event is emitted as expected
   */
  function test_emitEventFail(uint256 _amount, address _spender) external {
    vm.assume(_amount > 0);

    // Mock calls
    vm.mockCall(_messenger, abi.encodeWithSignature('xDomainMessageSender()'), abi.encode(_linkedAdapter));

    // Need to mock call, then mock the revert (foundry bug?)
    vm.mockCall(_usdc, abi.encodeWithSignature('mint(address,uint256)', _user, _amount), abi.encode(true));
    vm.mockCallRevert(_usdc, abi.encodeWithSignature('mint(address,uint256)', _user, _amount), abi.encode(false));

    // Execute
    vm.expectEmit(true, true, true, true);
    emit MessageFailed(_spender, _user, _amount, _messenger);

    vm.prank(_messenger);
    adapter.receiveMessage(_user, _spender, _amount);
  }
}

contract L2OpUSDCBridgeAdapter_Unit_WithdrawBlacklistedFunds is Base {
  event BlacklistedFundsWithdrawn(address indexed _user, uint256 _amountWithdrawn);
  event BlacklistedFundsSentBackToL1(address indexed _spender, uint256 _amountSent);

  /**
   * @notice Check that the function expects the correct calls
   */
  function test_expectedCallsIfNotDeprecated(uint256 _amount, address _user, address _spender) external {
    vm.assume(_amount > 0);
    vm.assume(_user != address(0));
    adapter.forTest_setUserBlacklistedFunds(_spender, _user, _amount);

    // Mock calls
    _mockAndExpect(_usdc, abi.encodeWithSignature('mint(address,uint256)', _user, _amount), abi.encode(true));

    // Execute
    vm.prank(_user);
    adapter.withdrawBlacklistedFunds(_spender, _user);
  }

  /**
   * @notice Check that the updates the state as expected
   */
  function test_updateStateIfNotDeprecated(uint256 _amount, address _user, address _spender) external {
    vm.assume(_amount > 0);
    vm.assume(_user != address(0));
    adapter.forTest_setUserBlacklistedFunds(_spender, _user, _amount);

    // Mock calls
    vm.mockCall(_usdc, abi.encodeWithSignature('mint(address,uint256)', _user, _amount), abi.encode(true));

    // Execute
    vm.prank(_user);
    adapter.withdrawBlacklistedFunds(_spender, _user);

    assertEq(adapter.blacklistedFundsDetails(_spender, _user), 0, 'User blacklisted funds should be updated');
  }

  function test_emitsEventIfNotDeprecated(uint256 _amount, address _user, address _spender) external {
    vm.assume(_amount > 0);
    vm.assume(_user != address(0));
    adapter.forTest_setUserBlacklistedFunds(_spender, _user, _amount);

    // Mock calls
    vm.mockCall(_usdc, abi.encodeWithSignature('mint(address,uint256)', _user, _amount), abi.encode(true));

    // Expect events
    vm.expectEmit(true, true, true, true);
    emit BlacklistedFundsWithdrawn(_user, _amount);

    // Execute
    vm.prank(_user);
    adapter.withdrawBlacklistedFunds(_spender, _user);
  }

  /**
   * @notice Check that the function expects the correct calls
   */
  function test_expectedCallsIfDeprecated(uint256 _amount, address _user, address _spender) external {
    adapter.forTest_setMessengerStatus(IOpUSDCBridgeAdapter.Status.Deprecated);
    vm.assume(_amount > 0);
    vm.assume(_spender != address(0));
    adapter.forTest_setUserBlacklistedFunds(_spender, _user, _amount);

    // Mock calls
    _mockAndExpect(
      _messenger,
      abi.encodeWithSignature(
        'sendMessage(address,bytes,uint32)',
        _linkedAdapter,
        abi.encodeWithSignature('receiveWithdrawBlacklistedFundsPostMigration(address,uint256)', _spender, _amount),
        150_000
      ),
      abi.encode()
    );

    // Execute
    vm.prank(_user);
    adapter.withdrawBlacklistedFunds(_spender, _user);
  }

  /**
   * @notice Check that the updates the state as expected
   */
  function test_updateStateIfDeprecated(uint256 _amount, address _user, address _spender) external {
    adapter.forTest_setMessengerStatus(IOpUSDCBridgeAdapter.Status.Deprecated);
    vm.assume(_amount > 0);
    vm.assume(_spender != address(0));
    adapter.forTest_setUserBlacklistedFunds(_spender, _user, _amount);

    // Mock calls
    _mockAndExpect(
      _messenger,
      abi.encodeWithSignature(
        'sendMessage(address,bytes,uint32)',
        _linkedAdapter,
        abi.encodeWithSignature('receiveWithdrawBlacklistedFundsPostMigration(address,uint256)', _spender, _amount),
        150_000
      ),
      abi.encode()
    );

    // Execute
    vm.prank(_user);
    adapter.withdrawBlacklistedFunds(_spender, _user);

    assertEq(adapter.blacklistedFundsDetails(_spender, _user), 0, 'User blacklisted funds should be updated');
  }

  function test_emitsEventIfDeprecated(uint256 _amount, address _user, address _spender) external {
    adapter.forTest_setMessengerStatus(IOpUSDCBridgeAdapter.Status.Deprecated);
    vm.assume(_amount > 0);
    vm.assume(_user != address(0));
    adapter.forTest_setUserBlacklistedFunds(_spender, _user, _amount);

    // Mock calls
    _mockAndExpect(
      _messenger,
      abi.encodeWithSignature(
        'sendMessage(address,bytes,uint32)',
        _linkedAdapter,
        abi.encodeWithSignature('receiveWithdrawBlacklistedFundsPostMigration(address,uint256)', _spender, _amount),
        150_000
      ),
      abi.encode()
    );

    // Expect events
    vm.expectEmit(true, true, true, true);
    emit BlacklistedFundsSentBackToL1(_spender, _amount);

    // Execute
    vm.prank(_user);
    adapter.withdrawBlacklistedFunds(_spender, _user);
  }
}

/*///////////////////////////////////////////////////////////////
                      BRIDGED USDC FUNCTIONS
///////////////////////////////////////////////////////////////*/
contract L2OpUSDCBridgeAdapter_Unit_CallUsdcTransaction is Base {
  /**
   * @notice Check that the function reverts if the sender is not the owner
   */
  function test_onlyOwner(address _notOwner, bytes calldata _data) external {
    vm.assume(_notOwner != _owner);
    // Execute
    vm.prank(_notOwner);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _notOwner));
    adapter.callUsdcTransaction(_data);
  }

  /**
   * @notice Check that the function reverts function selector is transferOwnership (0xf2fde38b)
   */
  function test_refevertoIfTxIsTransferOwnership(bytes memory _data) external {
    _data = bytes.concat(bytes4(0xf2fde38b), _data);
    // Execute
    vm.prank(_owner);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_ForbiddenTransaction.selector);
    adapter.callUsdcTransaction(_data);
  }

  /**
   * @notice Check that the function reverts function selector is changeAdmin (0x8f283970)
   */
  function test_revertIfTxIsChangeAdmin(bytes memory _data) external {
    _data = bytes.concat(bytes4(0x8f283970), _data);
    // Execute
    vm.prank(_owner);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_ForbiddenTransaction.selector);
    adapter.callUsdcTransaction(_data);
  }

  /**
   * @notice Check that the function reverts function selector is updateMasterMinter (0xaa20e1e4)
   */
  function test_revertIfTxIsUpdateMasterMinter(bytes memory _data) external {
    _data = bytes.concat(bytes4(0xaa20e1e4), _data);
    // Execute
    vm.prank(_owner);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_ForbiddenTransaction.selector);
    adapter.callUsdcTransaction(_data);
  }

  /**
   * @notice Check that the function upgradeTo gets called through the fallback admin
   */
  function test_upgradeTo(address _newImplementation) external {
    address _fallbackAdmin = address(adapter.FALLBACK_PROXY_ADMIN());

    _mockAndExpect(_fallbackAdmin, abi.encodeWithSignature('upgradeTo(address)', _newImplementation), abi.encode());
    vm.prank(_owner);
    adapter.callUsdcTransaction(abi.encodeWithSignature('upgradeTo(address)', _newImplementation));
  }

  /**
   * @notice Check that the function upgradeTo gets called through the fallback admin
   */
  function test_upgradeToAndCall(address _newImplementation, bytes memory _data) external {
    address _fallbackAdmin = address(adapter.FALLBACK_PROXY_ADMIN());

    _mockAndExpect(
      _fallbackAdmin,
      abi.encodeWithSignature('upgradeToAndCall(address,bytes)', _newImplementation, _data),
      abi.encode()
    );
    vm.prank(_owner);
    adapter.callUsdcTransaction(abi.encodeWithSignature('upgradeToAndCall(address,bytes)', _newImplementation, _data));
  }

  /**
   * @notice Check that the function upgradeTo reverts if the call reverts
   */
  function test_upgradeToRevert(address _newImplementation) external {
    address _fallbackAdmin = address(adapter.FALLBACK_PROXY_ADMIN());

    vm.mockCallRevert(
      _fallbackAdmin, abi.encodeWithSignature('upgradeTo(address)', _newImplementation), abi.encode(false, '')
    );
    vm.prank(_owner);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidTransaction.selector);
    adapter.callUsdcTransaction(abi.encodeWithSignature('upgradeTo(address)', _newImplementation));
  }

  /**
   * @notice Check that the function upgradeTo reverts if the call reverts
   */
  function test_upgradeToAndCallRevert(address _newImplementation, bytes memory _data) external {
    address _fallbackAdmin = address(adapter.FALLBACK_PROXY_ADMIN());

    vm.mockCallRevert(
      _fallbackAdmin,
      abi.encodeWithSignature('upgradeToAndCall(address,bytes)', _newImplementation, _data),
      abi.encode(false, '')
    );
    vm.prank(_owner);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidTransaction.selector);
    adapter.callUsdcTransaction(abi.encodeWithSignature('upgradeToAndCall(address,bytes)', _newImplementation, _data));
  }

  /**
   * @notice Check that reverts if a call reverts
   */
  function test_revertOnCallRevert(bytes memory _data) external {
    vm.assume(_data.length >= 4);
    // Mock calls
    vm.mockCallRevert(_usdc, _data, abi.encode(false, ''));

    // Execute
    vm.prank(_owner);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidTransaction.selector);
    adapter.callUsdcTransaction(_data);
  }

  /**
   * @notice Check that the message is sent as expected
   */
  function test_expectedCall(bytes calldata _data) external {
    vm.assume(_data.length >= 4);
    // Assume that the function selector is not upgradeTo or upgradeToAndCall so the call can be properly mocked
    bytes4 _selector = bytes4(_data);
    vm.assume(_selector != _UPGRADE_TO_SELECTOR && _selector != _UPGRADE_TO_AND_CALL_SELECTOR);

    _mockAndExpect(_usdc, _data, abi.encode(true, ''));

    // Execute
    vm.prank(_owner);
    adapter.callUsdcTransaction(_data);
  }

  /**
   * @notice Check that the event is emitted as expected
   */
  function test_emitEvent(bytes calldata _data) external {
    vm.assume(_data.length >= 4);
    // Assume that the function selector is not upgradeTo or upgradeToAndCall so the call can be properly mocked
    bytes4 _selector = bytes4(_data);
    vm.assume(_selector != _UPGRADE_TO_SELECTOR && _selector != _UPGRADE_TO_AND_CALL_SELECTOR);

    // Mock calls
    vm.mockCall(_usdc, _data, abi.encode(true, ''));

    // Expect events
    vm.expectEmit(true, true, true, true);
    emit USDCFunctionSent(bytes4(_data));

    // Execute
    vm.prank(_owner);
    adapter.callUsdcTransaction(_data);
  }
}

contract L2OpUSDCBridgeAdapter_Unit_Initialize is Base {
  /**
   * @notice Check that the initialize function works as expected
   * @dev Needs to be checked on the proxy since the initialize function is disabled on the implementation
   */
  function test_initialize(address _owner) public {
    vm.assume(_owner != address(0));

    // Deploy a proxy contract setting the , and call the initialize function on it to set the owner
    ForTestL2OpUSDCBridgeAdapter _newAdapter = ForTestL2OpUSDCBridgeAdapter(
      address(new ERC1967Proxy(address(_adapterImpl), abi.encodeCall(OpUSDCBridgeAdapter.initialize, _owner)))
    );

    // Assert
    assertEq(_newAdapter.owner(), _owner, 'Owner should be set to the provided address');
    assertGt(address(_newAdapter.FALLBACK_PROXY_ADMIN()).code.length, 0, 'Fallback admin was not deployed');
  }
}
