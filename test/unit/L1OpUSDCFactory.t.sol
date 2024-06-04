// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC1967Proxy} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import {L1OpUSDCBridgeAdapter} from 'contracts/L1OpUSDCBridgeAdapter.sol';
import {IL1OpUSDCFactory, L1OpUSDCFactory} from 'contracts/L1OpUSDCFactory.sol';
import {L2OpUSDCFactory} from 'contracts/L2OpUSDCFactory.sol';
import {UpgradeManager} from 'contracts/UpgradeManager.sol';
import {BytecodeDeployer} from 'contracts/utils/BytecodeDeployer.sol';
import {USDC_PROXY_CREATION_CODE} from 'contracts/utils/USDCProxyCreationCode.sol';
import {Test} from 'forge-std/Test.sol';
import {IUpgradeManager} from 'interfaces/IUpgradeManager.sol';
import {ICreate2Deployer} from 'interfaces/external/ICreate2Deployer.sol';
import {ICrossDomainMessenger} from 'interfaces/external/ICrossDomainMessenger.sol';
import {Helpers} from 'test/utils/Helpers.sol';

contract ForTestL1OpUSDCFactory is L1OpUSDCFactory {
  constructor(address _usdc, bytes32 _salt, address _owner) L1OpUSDCFactory(_usdc, _salt, _owner) {}

  function forTest_setIsMessengerDeployed(address _l1Messenger, bool _deployed) public {
    isMessengerDeployed[_l1Messenger] = _deployed;
  }

  function forTest_precalculateCreateAddress(
    address _deployer,
    uint256 _nonce
  ) public pure returns (address _precalculatedAddress) {
    _precalculatedAddress = _precalculateCreateAddress(_deployer, _nonce);
  }

  function forTest_precalculateCreate2Address(
    bytes32 _salt,
    bytes32 _initCodeHash,
    address _deployer
  ) public pure returns (address _precalculatedAddress) {
    _precalculatedAddress = _precalculateCreate2Address(_salt, _initCodeHash, _deployer);
  }
}

abstract contract Base is Test, Helpers {
  address internal constant _ZERO_ADDRESS = address(0);
  uint256 internal constant _ZERO_VALUE = 0;
  bytes32 internal constant _SALT = bytes32('1');

  ForTestL1OpUSDCFactory public factory;

  address internal _owner = makeAddr('owner');
  address internal _user = makeAddr('user');
  address internal _usdc = makeAddr('USDC');
  address internal _admin = makeAddr('admin');
  address internal _l2Messenger = makeAddr('l2Messenger');
  address internal _portal = makeAddr('portal');
  bytes internal _l2AdapterBytecode = '0x608061111111';
  bytes internal _l2UsdcProxyCreationCode = '0x6080222222';
  bytes internal _l2UsdcImplementationBytecode = '0x6080333333';
  // cant fuzz this because of foundry's VM
  address internal _l1Messenger = makeAddr('messenger');

  address internal _l2AdapterImplAddress = makeAddr('l2AdapterImpl');
  address internal _l2UsdcImplAddress = makeAddr('bridgedUsdcImpl');
  bytes internal _usdcInitTx = 'tx1';
  bytes internal _l2AdapterInitTx = 'tx2';
  bytes[] internal _usdcImplInitTxs;
  bytes[] internal _l2AdapterInitTxs;
  IUpgradeManager.Implementation internal _bridgedUsdcImplementation;
  IUpgradeManager.Implementation internal _l2AdapterImplementation;
  address internal _upgradeManager;

  function setUp() public {
    // Deploy factory
    factory = new ForTestL1OpUSDCFactory(_usdc, _SALT, _owner);
    _upgradeManager = address(factory.UPGRADE_MANAGER());

    vm.etch(_l2AdapterImplAddress, _l2AdapterBytecode);
    vm.etch(_l2UsdcImplAddress, _l2UsdcImplementationBytecode);

    // Define the implementation structs info
    _usdcImplInitTxs.push(_usdcInitTx);
    _l2AdapterInitTxs.push(_l2AdapterInitTx);
    _bridgedUsdcImplementation = IUpgradeManager.Implementation(_l2UsdcImplAddress, _usdcImplInitTxs);
    _l2AdapterImplementation = IUpgradeManager.Implementation(_l2AdapterImplAddress, _l2AdapterInitTxs);
  }

  /**
   * @notice Helper function to mock all the function calls that will be made in the `deployL2USDCAndAdapter` function,
   * and some that will be made in the `deployL2FactoryAndContracts` function
   */
  function _mockDeployFunctionCalls() internal {
    // Mock the user to be the executor
    vm.mockCall(
      _upgradeManager, abi.encodeWithSignature('messengerDeploymentExecutor(address)', _l1Messenger), abi.encode(_user)
    );

    // Mock the call over the `bridgedUSDCImplementation` function
    vm.mockCall(
      _upgradeManager,
      abi.encodeWithSelector(IUpgradeManager.bridgedUSDCImplementation.selector),
      abi.encode(_bridgedUsdcImplementation)
    );

    // Mock the call over the `l2AdapterImplementation` function
    vm.mockCall(
      _upgradeManager,
      abi.encodeWithSelector(IUpgradeManager.l2AdapterImplementation.selector),
      abi.encode(_l2AdapterImplementation)
    );

    // Mock the call over the `portal` function on the L1 messenger
    vm.mockCall(_l1Messenger, abi.encodeWithSelector(ICrossDomainMessenger.sendMessage.selector), abi.encode(''));
  }
}

contract L1OpUSDCFactory_Unit_Constructor is Base {
  event L1AdapterDeployed(address _l1AdapterProxy, address _l1AdapterImplementation);

  event UpgradeManagerDeployed(address _upgradeManagerProxy, address _upgradeManagerImplementation);

  /**
   * @notice Test the constructor params are correctly set
   */
  function test_setImmutables() public {
    address _wethL2 = 0x4200000000000000000000000000000000000006;
    // Get the init codes
    bytes memory _l2FactoryCreationCode = type(L2OpUSDCFactory).creationCode;
    bytes memory _l2FactoryCArgs = abi.encode(_SALT, address(factory));
    bytes32 _l2FactoryInitCodeHash = keccak256(bytes.concat(_l2FactoryCreationCode, _l2FactoryCArgs));
    bytes32 _l2UsdcProxyInitCodeHash = keccak256(bytes.concat(USDC_PROXY_CREATION_CODE, abi.encode(_wethL2)));
    bytes32 _l2AdapterProxyInitCodeHash =
      keccak256(bytes.concat(type(ERC1967Proxy).creationCode, abi.encode(_wethL2, '')));

    // Precalculate the addresses to be deployed using CREATE2
    address _l2Factory =
      factory.forTest_precalculateCreate2Address(_SALT, _l2FactoryInitCodeHash, factory.L2_CREATE2_DEPLOYER());
    address _l2UsdcProxyAddress =
      factory.forTest_precalculateCreate2Address(_SALT, _l2UsdcProxyInitCodeHash, address(_l2Factory));
    address _l2AdapterProxy =
      factory.forTest_precalculateCreate2Address(_SALT, _l2AdapterProxyInitCodeHash, address(_l2Factory));
    // Precalculate the addresses to be deployed using CREATE
    address _l1Adapter = factory.forTest_precalculateCreateAddress(address(factory), 2);
    address _upgradeManager = factory.forTest_precalculateCreateAddress(address(factory), 4);

    // Assert
    assertEq(factory.L2_FACTORY(), _l2Factory, 'Invalid l2Factory address');
    assertEq(factory.L2_USDC_PROXY(), _l2UsdcProxyAddress, 'Invalid l2UsdcProxy address');
    assertEq(factory.L2_ADAPTER_PROXY(), _l2AdapterProxy, 'Invalid l2Adapter proxy address');
    assertEq(address(factory.UPGRADE_MANAGER()), _upgradeManager, 'Invalid upgradeManager address');
    assertEq(address(factory.L1_ADAPTER_PROXY()), _l1Adapter, 'Invalid l1Adapter address');
  }

  /**
   * @notice Check the constructor correctly deploys the L1 adapter
   * @dev We are assuming the L1 adapter correctly sets the immutable vars to compare. Need to do this to check the
   * contract constructor values were properly set.
   */
  function test_deployL1Adapter() public {
    L1OpUSDCBridgeAdapter _l1Adapter = L1OpUSDCBridgeAdapter(factory.L1_ADAPTER_PROXY());
    assertEq(_l1Adapter.USDC(), _usdc, 'Invalid usdc');
    assertEq(_l1Adapter.LINKED_ADAPTER(), factory.L2_ADAPTER_PROXY(), 'Invalid l2Adapter');
    assertEq(address(_l1Adapter.UPGRADE_MANAGER()), address(factory.UPGRADE_MANAGER()), 'Invalid upgradeManager');
    assertEq(_l1Adapter.FACTORY(), address(factory), 'Invalid factory');
  }

  /**
   * @notice Check the `L1AdapterDeployed` event is properly emitted
   */
  function test_emitL1AdapterDeployedEvent() public {
    // Precalculate the L1 adapter address to be emitted
    uint256 _nonce = vm.getNonce(address(this));
    address _newFactory = factory.forTest_precalculateCreateAddress(address(this), _nonce);
    address _l1AdapterImpl = factory.forTest_precalculateCreateAddress(_newFactory, 1);
    address _l1AdapterProxy = factory.forTest_precalculateCreateAddress(_newFactory, 2);

    // Expect
    vm.expectEmit(true, true, true, true);
    emit L1AdapterDeployed(_l1AdapterProxy, _l1AdapterImpl);

    // Execute
    new ForTestL1OpUSDCFactory(_usdc, _SALT, _owner);
  }

  /**
   * @notice Check the constructor correctly deploys the upgrade manager implementation
   * @dev We are assuming the upgrade manager correctly sets the immutable vars to compare. Need to do this to check the
   * contract constructor values were properly set.
   */
  function test_deployUpgradeManagerImplementation() public {
    IUpgradeManager _upgradeManager = IUpgradeManager(address(factory.UPGRADE_MANAGER()));
    assertEq(_upgradeManager.L1_ADAPTER(), address(factory.L1_ADAPTER_PROXY()), 'Invalid l1Adapter');
  }

  /**
   * @notice Check the constructor correctly deploys the upgrade manager proxy
   * @dev We are assuming the upgrade manager correctly sets the immutable vars to compare. Need to do this to check the
   * contract constructor values were properly set.
   */
  function test_deployUpgradeManagerProxy() public {
    UpgradeManager _upgradeManager = UpgradeManager(address(factory.UPGRADE_MANAGER()));
    assertEq(_upgradeManager.owner(), _owner, 'Invalid owner');
  }

  /**
   * @notice Check the `UpgradeManagerDeployed` event is properly emitted
   */
  function test_emitUpgradeManagerDeployedEvent() public {
    // Precalculate the upgrade manager address to be emitted
    uint256 _nonce = vm.getNonce(address(this));
    address _newFactory = factory.forTest_precalculateCreateAddress(address(this), _nonce);
    address _upgradeManagerImpl = factory.forTest_precalculateCreateAddress(_newFactory, 3);
    address _upgradeManagerProxy = factory.forTest_precalculateCreateAddress(_newFactory, 4);

    // Expect
    vm.expectEmit(true, true, true, true);
    emit UpgradeManagerDeployed(_upgradeManagerProxy, _upgradeManagerImpl);

    // Execute
    new ForTestL1OpUSDCFactory(_usdc, _SALT, _owner);
  }
}

contract L1OpUSDCFactory_Unit_DeployL2FactoryAndContracts is Base {
  /**
   * @notice Check the `deployL2USDCAndAdapter` function reverts if the messenger already has a protocol deployed for it
   */
  function test_revertIfMessengerAlreadyDeployedFor(
    uint32 _minGasLimitCreate2Factory,
    uint32 _minGasLimitDeploy
  ) public {
    // Mock the `isMessengerDeployed` to return true
    factory.forTest_setIsMessengerDeployed(_l1Messenger, true);

    // Execute
    vm.expectRevert(IL1OpUSDCFactory.IL1OpUSDCFactory_MessengerAlreadyDeployed.selector);
    vm.prank(_user);
    factory.deployL2FactoryAndContracts(_l1Messenger, _admin, _minGasLimitCreate2Factory, _minGasLimitDeploy);
  }

  /**
   * @notice Check the `deployL2USDCAndAdapter` function reverts if the caller is not the executor
   */
  function test_revertIfNotExecutor(
    uint32 _minGasLimitCreate2Factory,
    uint32 _minGasLimitDeploy,
    address _executor
  ) public {
    vm.assume(_executor != _user);

    // Mock the `isMessengerDeployed` to return false
    factory.forTest_setIsMessengerDeployed(_l1Messenger, false);

    vm.mockCall(
      _upgradeManager,
      abi.encodeWithSignature('messengerDeploymentExecutor(address)', _l1Messenger),
      abi.encode(_executor)
    );

    // Execute
    vm.expectRevert(IL1OpUSDCFactory.IL1OpUSDCFactory_NotExecutor.selector);
    vm.prank(_user);
    factory.deployL2FactoryAndContracts(_l1Messenger, _admin, _minGasLimitCreate2Factory, _minGasLimitDeploy);
  }

  /**
   * @notice Check the `deployL2USDCAndAdapter` function calls the `messengerDeploymentExecutor` correctly
   */
  function test_callMessengerDeploymentExecutor(uint32 _minGasLimitCreate2Factory, uint32 _minGasLimitDeploy) public {
    // Mock all the `deployL2USDCAndAdapter` function calls
    _mockDeployFunctionCalls();

    // Expect the `bridgedUSDCImplementation` to be properly called
    vm.expectCall(_upgradeManager, abi.encodeWithSelector(IUpgradeManager.messengerDeploymentExecutor.selector));

    // Execute
    vm.prank(_user);
    factory.deployL2FactoryAndContracts(_l1Messenger, _admin, _minGasLimitCreate2Factory, _minGasLimitDeploy);
  }

  /**
   * @notice Check the messenger is set as deployed on the `isMessengerDeployed` mapping
   */
  function test_setMessengerDeployed(uint32 _minGasLimitCreate2Factory, uint32 _minGasLimitDeploy) public {
    // Mock all the `deployL2USDCAndAdapter` function calls
    _mockDeployFunctionCalls();

    // Execute
    vm.prank(_user);
    factory.deployL2FactoryAndContracts(_l1Messenger, _admin, _minGasLimitCreate2Factory, _minGasLimitDeploy);

    // Assert
    assertTrue(factory.isMessengerDeployed(_l1Messenger), 'Messenger not deployed');
  }

  /**
   * @notice Check the `deployL2USDCAndAdapter` function calls the `initializeNewMessenger` correctly
   */
  function test_callInitializeMessenger(uint32 _minGasLimitCreate2Factory, uint32 _minGasLimitDeploy) public {
    // Mock all the `deployL2USDCAndAdapter` function calls
    _mockDeployFunctionCalls();

    // Expect the `initializeMessenger` to be properly called
    vm.expectCall(
      address(factory.L1_ADAPTER_PROXY()),
      abi.encodeWithSelector(L1OpUSDCBridgeAdapter.initializeNewMessenger.selector, _l1Messenger)
    );

    // Execute
    vm.prank(_user);
    factory.deployL2FactoryAndContracts(_l1Messenger, _admin, _minGasLimitCreate2Factory, _minGasLimitDeploy);
  }

  /**
   * @notice Check the `deploy` call over the `create2Deployer` is correctly sent through the messenger
   */
  function test_callSendMessage(uint32 _minGasLimitCreate2Factory, uint32 _minGasLimitDeploy) public {
    // Mock all the `deployL2USDCAndAdapter` function calls
    _mockDeployFunctionCalls();

    // Get the L2 factory deployment tx
    bytes memory _l2FactoryCreationCode = type(L2OpUSDCFactory).creationCode;
    bytes memory _l2FactoryCArgs = abi.encode(_SALT, address(factory));
    bytes memory _l2FactoryInitCode = bytes.concat(_l2FactoryCreationCode, _l2FactoryCArgs);
    bytes memory _l2FactoryCreate2Tx =
      abi.encodeWithSelector(ICreate2Deployer.deploy.selector, _ZERO_VALUE, _SALT, _l2FactoryInitCode);

    // Expect the `sendMessage` to be properly called
    vm.expectCall(
      _l1Messenger,
      abi.encodeWithSelector(
        ICrossDomainMessenger.sendMessage.selector,
        factory.L2_CREATE2_DEPLOYER(),
        _l2FactoryCreate2Tx,
        _minGasLimitCreate2Factory
      )
    );

    // Execute
    vm.prank(_user);
    factory.deployL2FactoryAndContracts(_l1Messenger, _admin, _minGasLimitCreate2Factory, _minGasLimitDeploy);
  }

  /**
   * @notice Check the `_deployL2USDCAndAdapter` function is called on the `deployL2USDCAndAdapter` function by checking
   * that the message to deploy those L2 contracts is properly sent
   */
  function test_callDeployL2USDCAndAdapter(uint32 _minGasLimitCreate2Factory, uint32 _minGasLimitDeploy) public {
    // Mock all the `deployL2USDCAndAdapter` function calls
    _mockDeployFunctionCalls();

    // Expect the `sendMessage` to be properly called
    bytes memory _l2DeploymentsTx = abi.encodeWithSelector(
      L2OpUSDCFactory.deploy.selector,
      _l2UsdcImplementationBytecode,
      _usdcImplInitTxs,
      _admin,
      _l2AdapterBytecode,
      _l2AdapterInitTxs
    );
    vm.expectCall(
      _l1Messenger,
      abi.encodeWithSelector(
        ICrossDomainMessenger.sendMessage.selector, factory.L2_FACTORY(), _l2DeploymentsTx, _minGasLimitDeploy
      )
    );

    // Execute
    vm.prank(_user);
    factory.deployL2FactoryAndContracts(_l1Messenger, _admin, _minGasLimitCreate2Factory, _minGasLimitDeploy);
  }
}

contract L1OpUSDCFactory_Unit_DeployL2USDCAndAdapter is Base {
  /**
   * @notice Check the `deployL2USDCAndAdapter` function reverts if the caller is not the executor
   */
  function test_revertIfNotExecutor(uint32 _minGasLimitDeploy, address _executor) public {
    vm.assume(_executor != _user);

    // Mock the `isMessengerDeployed` to return false
    factory.forTest_setIsMessengerDeployed(_l1Messenger, false);

    vm.mockCall(
      _upgradeManager,
      abi.encodeWithSignature('messengerDeploymentExecutor(address)', _l1Messenger),
      abi.encode(_executor)
    );

    // Execute
    vm.expectRevert(IL1OpUSDCFactory.IL1OpUSDCFactory_NotExecutor.selector);
    vm.prank(_user);
    factory.deployL2USDCAndAdapter(_l1Messenger, _admin, _minGasLimitDeploy);
  }

  /**
   * @notice Check the `deployL2USDCAndAdapter` function calls the `messengerDeploymentExecutor` correctly
   */
  function test_callMessengerDeploymentExecutor(uint32 _minGasLimitDeploy) public {
    // Mock all the `deployL2USDCAndAdapter` function calls
    _mockDeployFunctionCalls();

    // Expect the `bridgedUSDCImplementation` to be properly called
    vm.expectCall(_upgradeManager, abi.encodeWithSelector(IUpgradeManager.messengerDeploymentExecutor.selector));

    // Execute
    vm.prank(_user);
    factory.deployL2USDCAndAdapter(_l1Messenger, _admin, _minGasLimitDeploy);
  }

  function test_revertIfInvalidUSDCAdmin(uint32 _minGasLimitCreate2Factory, uint32 _minGasLimitDeploy) public {
    // Mock all the `deployL2USDCAndAdapter` function calls
    _mockDeployFunctionCalls();

    address _admin2 = factory.L2_FACTORY();
    vm.expectRevert(IL1OpUSDCFactory.IL1OpUSDCFactory_InvalidUSDCAdmin.selector);
    vm.prank(_user);
    factory.deployL2FactoryAndContracts(_l1Messenger, _admin2, _minGasLimitCreate2Factory, _minGasLimitDeploy);
  }

  function test_callBridgedUSDCImplementation(uint32 _minGasLimitDeploy) public {
    // Mock all the `deployL2USDCAndAdapter` function calls
    _mockDeployFunctionCalls();

    // Expect the `bridgedUSDCImplementation` to be properly called
    vm.expectCall(_upgradeManager, abi.encodeWithSelector(IUpgradeManager.bridgedUSDCImplementation.selector));

    // Execute
    vm.prank(_user);
    factory.deployL2USDCAndAdapter(_l1Messenger, _admin, _minGasLimitDeploy);
  }

  /**
   * @notice Check the `deployL2USDCAndAdapter` function calls the `l2AdapterImplementation` correctly
   */
  function test_callL2AdapterImplementation(uint32 _minGasLimitDeploy) public {
    // Mock all the `deployL2USDCAndAdapter` function calls
    _mockDeployFunctionCalls();

    // Expect the `l2AdapterImplementation` to be properly called
    vm.expectCall(_upgradeManager, abi.encodeWithSelector(IUpgradeManager.l2AdapterImplementation.selector));

    // Execute
    vm.prank(_user);
    factory.deployL2USDCAndAdapter(_l1Messenger, _admin, _minGasLimitDeploy);
  }

  /**
   * @notice Check the `_deployL2USDCAndAdapter` function calls the `sendMessage` correctly. We use a for test function
   * to get the internal because the `sendMessage` function is not public
   */
  function test_callSendMessage(uint32 _minGasLimitDeploy) public {
    // Mock all the `deployL2USDCAndAdapter` function calls
    _mockDeployFunctionCalls();

    // Expect the `sendMessage` to be properly called
    bytes memory _l2DeploymentsTx = abi.encodeWithSelector(
      L2OpUSDCFactory.deploy.selector,
      _l2UsdcImplementationBytecode,
      _usdcImplInitTxs,
      _admin,
      _l2AdapterBytecode,
      _l2AdapterInitTxs
    );
    vm.expectCall(
      _l1Messenger,
      abi.encodeWithSelector(
        ICrossDomainMessenger.sendMessage.selector, factory.L2_FACTORY(), _l2DeploymentsTx, _minGasLimitDeploy
      )
    );

    // Execute
    vm.prank(_user);
    factory.deployL2USDCAndAdapter(_l1Messenger, _admin, _minGasLimitDeploy);
  }
}

contract L1OpUSDCFactory_Unit_PrecalculateCreateAddress is Base {
  /**
   * @notice Check the `precalculateCreateAddress` function returns the correct address for the given deployer and nonce
   * We are testing the range from 1 to 127 since the function only covers that range which is enough for the factory
   */
  function test_precalculateCreateAddress(address _deployer) public {
    vm.setNonce(_deployer, 1);
    for (uint256 i = 1; i < 127; i++) {
      // Precalculate the address
      address _precalculatedAddress = factory.forTest_precalculateCreateAddress(_deployer, i);

      // Execute
      vm.prank(_deployer);
      address _newAddress = address(new ForTest_DummyContract());

      // Assert
      assertEq(_newAddress, _precalculatedAddress, 'Invalid create precalculated address');
    }
  }
}

contract L1OpUSDCFactory_Unit_PrecalculateCreate2Address is Base {
  // Error to revert when the create2 fails while testing the precalculateCreate2Address function
  error Create2Failed();

  /**
   * @notice Check the `precalculateCreate2Address` function returns the correct address for the given salt, init code
   *  hash, and deployer
   */
  function test_precalculateCreate2Address(bytes32 _salt, address _deployer) public {
    // Get the dumy contract init code and its hash
    bytes memory _initCode = type(ForTest_DummyContract).creationCode;
    bytes32 _initCodeHash = keccak256(_initCode);

    // Precalculate the address
    address _precalculatedAddress = factory.forTest_precalculateCreate2Address(_salt, _initCodeHash, _deployer);
    address _newAddress;

    // Execute
    vm.prank(_deployer);
    assembly ("memory-safe") {
      _newAddress := create2(callvalue(), add(_initCode, 0x20), mload(_initCode), _salt)
    }
    if (_newAddress == address(0) || _newAddress.code.length == 0) {
      revert Create2Failed();
    }

    // Assert
    assertEq(_newAddress, _precalculatedAddress, 'Invalid create2 precalculated address');
  }
}

/**
 * @notice Dummy contract to be deployed only for testing purposes
 */
contract ForTest_DummyContract {}
