pragma solidity 0.8.25;

import {ERC1967Proxy} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import {IUpgradeManager, UpgradeManager} from 'contracts/UpgradeManager.sol';
import {IL1OpUSDCBridgeAdapter} from 'interfaces/IL1OpUSDCBridgeAdapter.sol';
import {Helpers} from 'test/utils/Helpers.sol';

contract ForTestUpgradeManager is UpgradeManager {
  constructor(address _l1Adapter) UpgradeManager(_l1Adapter) {}

  function forTest_setMigrationsExecuted(address _l1Messenger) public {
    migrations[_l1Messenger].executed = true;
  }

  function forTest_setMigrationsCircle(address _l1Messenger, address _circle) public {
    migrations[_l1Messenger].circle = _circle;
  }

  function forTest_setMigrationsExecutor(address _l1Messenger, address _executor) public {
    migrations[_l1Messenger].executor = _executor;
  }
}

abstract contract Base is Helpers {
  ForTestUpgradeManager public upgradeManager;
  ForTestUpgradeManager public implementation;

  address internal _l1Adapter = makeAddr('l1Adapter');
  address internal _owner = makeAddr('owner');
  address internal _user = makeAddr('user');

  event MigrationPrepared(address indexed l1Messenger, address indexed circle, address indexed executor);
  event MigrationExecuted(address indexed l1Messenger, address indexed circle, address indexed executor);
  event L1AdapterImplementationSet(address indexed implementation);
  event L2AdapterImplementationSet(address indexed implementation);
  event MessengerWhitelisted(address l1Messenger);
  event BridgedUSDCImplementationSet(address indexed implementation);
  event Initialized(uint64);

  error OwnableUnauthorizedAccount(address);

  function setUp() public virtual {
    vm.prank(_owner);
    implementation = new ForTestUpgradeManager(_l1Adapter);
    bytes memory _data = abi.encodeWithSignature('initialize(address)', _owner);
    upgradeManager = ForTestUpgradeManager(address(new ERC1967Proxy(address(implementation), _data)));
  }
}

contract UpgradeManager_Unit_Constructor is Base {
  /**
   * @notice Check that the constructor works as expected
   */
  function test_constructorParams() public {
    assertEq(upgradeManager.L1_ADAPTER(), _l1Adapter, 'L1_ADAPTER should be set to the provided address');
  }

  /**
   * @notice Check that the constructor emits the expected event after disabling initializers
   */
  function test_initializerDisabled() public {
    vm.expectEmit(true, true, true, true);
    emit Initialized(type(uint64).max);
    new ForTestUpgradeManager(_l1Adapter);
  }
}

contract UpgradeManager_Unit_Initialize is Base {
  /**
   * @notice Check that the initialize function works as expected
   */
  function test_initialize() public {
    assertEq(upgradeManager.owner(), _owner, 'Owner should be set to the provided address');
  }
}

contract UpgradeManager_Unit_SetL2AdapterImplementation is Base {
  /**
   * @notice Check that the setL2AdapterImplementation function reverts when called by an unauthorized account
   */
  function test_revertIfNotOwner(address _newImplementation) public {
    vm.prank(_user);
    vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, _user));
    upgradeManager.setL2AdapterImplementation(_newImplementation);
  }

  /**
   * @notice Check that the setL2AdapterImplementation function works as expected
   */
  function test_setL2AdapterImplementation(address _newImplementation) public {
    vm.prank(_owner);
    upgradeManager.setL2AdapterImplementation(_newImplementation);
    assertEq(
      upgradeManager.l2AdapterImplementation(),
      _newImplementation,
      'L2 Adapter Implementation should be set to the provided address'
    );
  }

  /**
   * @notice Check that the setL2AdapterImplementation function emits the expected event
   */
  function test_emitsEvent(address _newImplementation) public {
    vm.prank(_owner);
    vm.expectEmit(true, true, true, true);
    emit L2AdapterImplementationSet(_newImplementation);
    upgradeManager.setL2AdapterImplementation(_newImplementation);
  }
}

contract UpgradeManager_Unit_SetBridgedUSDCImplementation is Base {
  /**
   * @notice Check that the setBridgedUSDCImplementation function reverts when called by an unauthorized account
   */
  function test_revertIfNotOwner(address _newImplementation) public {
    vm.prank(_user);
    vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, _user));
    upgradeManager.setBridgedUSDCImplementation(_newImplementation);
  }

  /**
   * @notice Check that the setBridgedUSDCImplementation function works as expected
   */
  function test_setBridgedUSDCImplementation(address _newImplementation) public {
    vm.prank(_owner);
    upgradeManager.setBridgedUSDCImplementation(_newImplementation);
    assertEq(
      upgradeManager.bridgedUSDCImplementation(),
      _newImplementation,
      'Bridged USDC Implementation should be set to the provided address'
    );
  }

  /**
   * @notice Check that the setBridgedUSDCImplementation function emits the expected event
   */
  function test_emitsEvent(address _newImplementation) public {
    vm.prank(_owner);
    vm.expectEmit(true, true, true, true);
    emit BridgedUSDCImplementationSet(_newImplementation);
    upgradeManager.setBridgedUSDCImplementation(_newImplementation);
  }
}

contract UpgradeManager_Unit_WhitelistMessenger is Base {
  /**
   * @notice Check that the whitelistMessenger function reverts when called by an unauthorized account
   */
  function test_revertIfNotOwner(address _newMessenger) public {
    vm.prank(_user);
    vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, _user));
    upgradeManager.whitelistMessenger(_newMessenger);
  }

  /**
   * @notice Check that the whitelistMessenger function works as expected
   */
  function test_whitelistMessenger(address _newMessenger) public {
    vm.prank(_owner);
    upgradeManager.whitelistMessenger(_newMessenger);
    assertEq(upgradeManager.isL1MessengerWhitelisted(_newMessenger), true, 'Messenger should be whitelisted');
  }

  /**
   * @notice Check that the whitelistMessenger function emits the expected event
   */
  function test_emitsEvent(address _newMessenger) public {
    vm.prank(_owner);
    vm.expectEmit(true, true, true, true);
    emit MessengerWhitelisted(_newMessenger);
    upgradeManager.whitelistMessenger(_newMessenger);
  }
}

contract UpgradeManager_Unit_PrepareMigrateToNative is Base {
  /**
   * @notice Check that the prepareMigrateToNative function reverts if the owner doesnt call it
   */
  function test_revertIfNotCalledByOwner(address _l1Messenger, address _circle, address _executor) public {
    vm.prank(_user);
    vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, _user));
    upgradeManager.prepareMigrateToNative(_l1Messenger, _circle, _executor);
  }

  /**
   * @notice Check that the prepareMigrateToNative function reverts if the migration is already executed
   */
  function test_revertIfMigrationAlreadyExecuted(address _l1Messenger, address _circle, address _executor) public {
    upgradeManager.forTest_setMigrationsExecuted(_l1Messenger);

    vm.prank(_owner);
    vm.expectRevert(abi.encodeWithSelector(IUpgradeManager.IUpgradeManager_MigrationAlreadyExecuted.selector));
    upgradeManager.prepareMigrateToNative(_l1Messenger, _circle, _executor);
  }

  /**
   * @notice Check that the prepareMigrateToNative function works as expected
   */
  function test_prepareMigrateToNative(address _l1Messenger, address _circle, address _executor) public {
    vm.prank(_owner);
    upgradeManager.prepareMigrateToNative(_l1Messenger, _circle, _executor);

    (address _savedCircle, address _savedExecutor, bool _executed) = upgradeManager.migrations(_l1Messenger);

    assertEq(_savedCircle, _circle, 'Circle should be set to the provided address');
    assertEq(_savedExecutor, _executor, 'Executor should be set to the provided address');
    assertEq(_executed, false, 'Executed should be set to false');
  }

  /**
   * @notice Check that the prepareMigrateToNative function emits the expected event
   */
  function test_emitsEvent(address _l1Messenger, address _circle, address _executor) public {
    vm.prank(_owner);
    vm.expectEmit(true, true, true, true);
    emit MigrationPrepared(_l1Messenger, _circle, _executor);
    upgradeManager.prepareMigrateToNative(_l1Messenger, _circle, _executor);
  }
}

contract UpgradeManager_Unit_ResumeMessaging is Base {
  /**
   * @notice Check that the resumeMessaging function reverts when called by an unauthorized account
   */
  function test_revertIfNotOwner(address _messenger, uint32 _minGasLimit) public {
    vm.prank(_user);
    vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, _user));
    upgradeManager.resumeMessaging(_messenger, _minGasLimit);
  }

  /**
   * @notice Check that the resumeMessaging function works as expected
   */
  function test_resumeMessaging(address _messenger, uint32 _minGasLimit) public {
    _mockAndExpect(
      _l1Adapter,
      abi.encodeWithSelector(IL1OpUSDCBridgeAdapter.resumeMessaging.selector, _messenger, _minGasLimit),
      abi.encode()
    );

    vm.prank(_owner);
    upgradeManager.resumeMessaging(_messenger, _minGasLimit);
  }
}

contract UpgradeManager_Unit_StopMessaging is Base {
  /**
   * @notice Check that the stopMessaging function reverts when called by an unauthorized account
   */
  function test_revertIfNotOwner(uint32 _minGasLimit, address _messenger) public {
    vm.prank(_user);
    vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, _user));
    upgradeManager.stopMessaging(_messenger, _minGasLimit);
  }

  /**
   * @notice Check that the stopMessaging function works as expected
   */
  function test_stopMessaging(uint32 _minGasLimit, address _messenger) public {
    _mockAndExpect(
      _l1Adapter,
      abi.encodeWithSelector(IL1OpUSDCBridgeAdapter.stopMessaging.selector, _minGasLimit, _messenger),
      abi.encode()
    );

    vm.prank(_owner);
    upgradeManager.stopMessaging(_messenger, _minGasLimit);
  }
}

contract UpgradeManager_Unit_ExecuteMigration is Base {
  /**
   * @notice Check that the executeMigration function reverts if the migration is not prepared
   */
  function test_revertIfMigrationNotPrepared(address _l1Messenger, address _circle) public {
    vm.assume(_circle != address(0));
    upgradeManager.forTest_setMigrationsCircle(_l1Messenger, _circle);

    vm.expectRevert(abi.encodeWithSelector(IUpgradeManager.IUpgradeManager_MigrationNotPrepared.selector));
    upgradeManager.executeMigration(_l1Messenger);
  }

  /**
   * @notice Check that the executeMigration function reverts if the migration is not prepared
   */
  function test_revertIfMigrationNotPreparedProperly(address _l1Messenger, address _executor) public {
    vm.assume(_executor != address(0));
    upgradeManager.forTest_setMigrationsExecutor(_l1Messenger, _executor);

    vm.expectRevert(abi.encodeWithSelector(IUpgradeManager.IUpgradeManager_MigrationNotPrepared.selector));
    upgradeManager.executeMigration(_l1Messenger);
  }

  /**
   * @notice Check that the executeMigration function reverts if the migration is already executed
   */
  function test_revertIfMigrationAlreadyExecuted(address _l1Messenger, address _executor, address _circle) public {
    vm.assume(_circle != address(0));
    vm.assume(_executor != address(0));

    upgradeManager.forTest_setMigrationsCircle(_l1Messenger, _circle);
    upgradeManager.forTest_setMigrationsExecutor(_l1Messenger, _executor);
    upgradeManager.forTest_setMigrationsExecuted(_l1Messenger);

    vm.expectRevert(abi.encodeWithSelector(IUpgradeManager.IUpgradeManager_MigrationAlreadyExecuted.selector));
    upgradeManager.executeMigration(_l1Messenger);
  }

  /**
   * @notice Check that the executeMigration function reverts if the caller is not the executor
   */
  function test_revertIfNotExecutor(address _l1Messenger, address _circle, address _executor) public {
    vm.assume(_circle != address(0));
    vm.assume(_executor != address(0));
    vm.assume(_executor != _user);

    upgradeManager.forTest_setMigrationsCircle(_l1Messenger, _circle);
    upgradeManager.forTest_setMigrationsExecutor(_l1Messenger, _executor);

    vm.prank(_user);
    vm.expectRevert(abi.encodeWithSelector(IUpgradeManager.IUpgradeManager_NotExecutor.selector));
    upgradeManager.executeMigration(_l1Messenger);
  }

  /**
   * @notice Check that the executeMigration function works as expected
   */
  function test_executeMigration(address _l1Messenger, address _circle, address _executor) public {
    vm.assume(_circle != address(0));
    vm.assume(_executor != address(0));

    upgradeManager.forTest_setMigrationsCircle(_l1Messenger, _circle);
    upgradeManager.forTest_setMigrationsExecutor(_l1Messenger, _executor);

    _mockAndExpect(
      _l1Adapter,
      abi.encodeWithSelector(IL1OpUSDCBridgeAdapter.migrateToNative.selector, _l1Messenger, _circle),
      abi.encode()
    );
    vm.prank(_executor);
    upgradeManager.executeMigration(_l1Messenger);

    (address _savedCircle, address _savedExecutor, bool _executed) = upgradeManager.migrations(_l1Messenger);

    assertEq(_savedCircle, _circle, 'Circle should be set to the provided address');
    assertEq(_savedExecutor, _executor, 'Executor should be set to the provided address');
    assertEq(_executed, true, 'Executed should be set to true');
  }

  /**
   * @notice Check that the executeMigration function emits the expected event
   */
  function test_emitsEvent(address _l1Messenger, address _circle, address _executor) public {
    vm.assume(_circle != address(0));
    vm.assume(_executor != address(0));

    upgradeManager.forTest_setMigrationsCircle(_l1Messenger, _circle);
    upgradeManager.forTest_setMigrationsExecutor(_l1Messenger, _executor);

    _mockAndExpect(
      _l1Adapter,
      abi.encodeWithSelector(IL1OpUSDCBridgeAdapter.migrateToNative.selector, _l1Messenger, _circle),
      abi.encode()
    );
    vm.prank(_executor);
    vm.expectEmit(true, true, true, true);
    emit MigrationExecuted(_l1Messenger, _circle, _executor);
    upgradeManager.executeMigration(_l1Messenger);
  }
}

contract UpgradeManager_Unit_UpgradeToAndCall is Base {
  /**
   * @notice Check that the _authorizeUpgrade function reverts when called by an unauthorized account
   */
  function test_revertIfNotOwner(address _newImplementation) public {
    vm.prank(_user);
    vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, _user));
    upgradeManager.upgradeToAndCall(_newImplementation, '');
  }

  /**
   * @notice Check that the _authorizeUpgrade function works as expected
   */
  function test_authorizeUpgrade() public {
    address _newImplementation = address(new ForTestUpgradeManager(_l1Adapter));
    vm.prank(_owner);
    upgradeManager.upgradeToAndCall(_newImplementation, '');
  }
}
