pragma solidity ^0.8.25;

import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {ERC1967Proxy} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import {L1OpUSDCBridgeAdapter} from 'contracts/L1OpUSDCBridgeAdapter.sol';
import {IOpUSDCBridgeAdapter} from 'interfaces/IOpUSDCBridgeAdapter.sol';
import {Helpers} from 'test/utils/Helpers.sol';

contract ForTestL1OpUSDCBridgeAdapter is L1OpUSDCBridgeAdapter {
  constructor(
    address _usdc,
    address _messenger,
    address _linkedAdapter,
    address _upgradeManager
  ) L1OpUSDCBridgeAdapter(_usdc, _messenger, _linkedAdapter, _upgradeManager) {}

  function forTest_setIsMessagingDisabled() external {
    isMessagingDisabled = true;
  }

  function forTest_setBurnAmount(uint256 _amount) external {
    burnAmount = _amount;
  }
}

abstract contract Base is Helpers {
  ForTestL1OpUSDCBridgeAdapter public adapter;
  ForTestL1OpUSDCBridgeAdapter public implementation;

  address internal _user = makeAddr('user');
  address internal _usdc = makeAddr('opUSDC');
  address internal _messenger = makeAddr('messenger');
  address internal _linkedAdapter = makeAddr('linkedAdapter');
  address internal _upgradeManager = makeAddr('upgradeManager');

  event MessageSent(address _user, address _to, uint256 _amount, uint32 _minGasLimit);
  event MessageReceived(address _user, uint256 _amount);
  event BurnAmountSet(uint256 _burnAmount);
  event L2AdapterUpgradeSent(address _newImplementation, bytes _data, uint32 _minGasLimit);

  function setUp() public virtual {
    implementation = new ForTestL1OpUSDCBridgeAdapter(_usdc, _messenger, _linkedAdapter, _upgradeManager);
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
    assertEq(adapter.MESSENGER(), _messenger, 'Messenger should be set to the provided address');
    assertEq(adapter.LINKED_ADAPTER(), _linkedAdapter, 'Linked adapter should be set to the provided address');
  }
}

contract L1OpUSDCBridgeAdapter_Unit_UpgradeToAndCall is Base {
  /**
   * @notice Check that only the owner can upgrade the contract
   */
  function test_onlyUpgradeManager(address _newImplementation, bytes memory _data) external {
    // Execute
    vm.prank(_user);
    vm.expectRevert(abi.encodeWithSelector(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidSender.selector));
    adapter.upgradeToAndCall(_newImplementation, _data);
  }

  /**
   * @notice Check that the upgrade is called as expected
   */
  function test_callUpgradeToAndCall() external {
    address _newImplementation =
      address(new ForTestL1OpUSDCBridgeAdapter(_usdc, _messenger, _linkedAdapter, _upgradeManager));
    // Execute
    vm.prank(_upgradeManager);
    adapter.upgradeToAndCall(_newImplementation, '');
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

contract L1OpUSDCBridgeAdapter_Unit_BurnLockedUSDC is Base {
  /**
   * @notice Check that only the owner can burn the locked USDC
   */
  function test_onlyUpgradeManager() external {
    // Execute
    vm.prank(_user);
    vm.expectRevert(abi.encodeWithSelector(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidSender.selector));
    adapter.burnLockedUSDC();
  }

  /**
   * @notice Check that the burn function is called as expected
   */
  function test_expectedCall(uint256 _burnAmount) external {
    vm.assume(_burnAmount > 0);

    _mockAndExpect(
      address(_usdc), abi.encodeWithSignature('burn(address,uint256)', address(adapter), _burnAmount), abi.encode(true)
    );

    adapter.forTest_setBurnAmount(_burnAmount);

    // Execute
    vm.prank(_upgradeManager);
    adapter.burnLockedUSDC();
  }

  /**
   * @notice Check that the burn amount is set to 0 after burning
   */
  function test_resetBurnAmount(uint256 _burnAmount) external {
    vm.assume(_burnAmount > 0);

    vm.mockCall(
      address(_usdc), abi.encodeWithSignature('burn(address,uint256)', address(adapter), _burnAmount), abi.encode(true)
    );

    adapter.forTest_setBurnAmount(_burnAmount);

    // Execute
    vm.prank(_upgradeManager);
    adapter.burnLockedUSDC();

    assertEq(adapter.burnAmount(), 0, 'Burn amount should be set to 0');
  }
}

contract L1OpUSDCBridgeAdapter_Unit_SendMessage is Base {
  /**
   * @notice Check that the function reverts if messaging is disabled
   */
  function test_revertOnMessagingDisabled(address _to, uint256 _amount, uint32 _minGasLimit) external {
    adapter.forTest_setIsMessagingDisabled();

    // Execute
    vm.prank(_user);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_MessagingDisabled.selector);
    adapter.sendMessage(_to, _amount, _minGasLimit);
  }

  /**
   * @notice Check that transferFrom and sendMessage are called as expected
   */
  function test_expectedCall(address _to, uint256 _amount, uint32 _minGasLimit) external {
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
    adapter.sendMessage(_to, _amount, _minGasLimit);
  }

  /**
   * @notice Check that the event is emitted as expected
   */
  function test_emitEvent(address _to, uint256 _amount, uint32 _minGasLimit) external {
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
    emit MessageSent(_user, _to, _amount, _minGasLimit);

    // Execute
    vm.prank(_user);
    adapter.sendMessage(_to, _amount, _minGasLimit);
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
    adapter.sendL2AdapterUpgrade(_newImplementation, _data, _minGasLimit);
  }

  /**
   * @notice Check that the message is sent as expected
   */
  function test_expectedCall(address _newImplementation, bytes memory _data, uint32 _minGasLimit) external {
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
    adapter.sendL2AdapterUpgrade(_newImplementation, _data, _minGasLimit);
  }

  /**
   * @notice Check that the event is emitted as expected
   */
  function test_emitEvent(address _newImplementation, bytes memory _data, uint32 _minGasLimit) external {
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
    emit L2AdapterUpgradeSent(_newImplementation, _data, _minGasLimit);

    // Execute
    vm.prank(_upgradeManager);
    adapter.sendL2AdapterUpgrade(_newImplementation, _data, _minGasLimit);
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

contract L1OpUSDCBridgeAdapter_Unit_StopMessaging is Base {
  event MessagingStopped();

  /**
   * @notice Check that only the owner can stop messaging
   */
  function test_onlyUpgradeManager() public {
    // Execute
    vm.prank(_user);
    vm.expectRevert(abi.encodeWithSelector(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidSender.selector));
    adapter.stopMessaging(0);
  }

  /**
   * @notice Check that the function reverts if messaging is already disabled
   */
  function test_revertIfMessagingIsAlreadyDisabled(uint32 _minGasLimit) public {
    adapter.forTest_setIsMessagingDisabled();

    // Execute
    vm.prank(_upgradeManager);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_MessagingDisabled.selector);
    adapter.stopMessaging(_minGasLimit);
  }

  /**
   * @notice Check that isMessagingDisabled is set to true
   */
  function test_setIsMessagingDisabledToTrue(uint32 _minGasLimit) public {
    bytes memory _messageData = abi.encodeWithSignature('receiveStopMessaging()');

    _mockAndExpect(
      _messenger,
      abi.encodeWithSignature('sendMessage(address,bytes,uint32)', _linkedAdapter, _messageData, _minGasLimit),
      abi.encode('')
    );

    // Execute
    vm.prank(_upgradeManager);
    adapter.stopMessaging(_minGasLimit);
    assertEq(adapter.isMessagingDisabled(), true, 'Messaging should be disabled');
  }

  /**
   * @notice Check that the event is emitted as expected
   */
  function test_emitEvent(uint32 _minGasLimit) public {
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
    vm.prank(_upgradeManager);
    adapter.stopMessaging(_minGasLimit);
  }
}
