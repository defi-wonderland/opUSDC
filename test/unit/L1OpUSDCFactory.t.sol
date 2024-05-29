// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {L1OpUSDCBridgeAdapter} from 'contracts/L1OpUSDCBridgeAdapter.sol';
import {IL1OpUSDCFactory, L1OpUSDCFactory} from 'contracts/L1OpUSDCFactory.sol';
import {L2OpUSDCFactory} from 'contracts/L2OpUSDCFactory.sol';
import {UpgradeManager} from 'contracts/UpgradeManager.sol';
import {USDC_PROXY_CREATION_CODE} from 'contracts/utils/USDCProxyCreationCode.sol';
import {Test} from 'forge-std/Test.sol';
import {IUpgradeManager} from 'interfaces/IUpgradeManager.sol';
import {ICrossDomainMessenger} from 'interfaces/external/ICrossDomainMessenger.sol';
import {IOptimismPortal} from 'interfaces/external/IOptimismPortal.sol';
import {AddressAliasHelper} from 'test/utils/AddressAliasHelper.sol';
import {Helpers} from 'test/utils/Helpers.sol';

contract ForTestL1OpUSDCFactory is L1OpUSDCFactory {
  constructor(address _usdc, address _owner) L1OpUSDCFactory(_usdc, _owner) {}

  function forTest_setIsMessengerDeployed(address _l1Messenger, bool _deployed) public {
    isMessengerDeployed[_l1Messenger] = _deployed;
  }
}

abstract contract Base is Test, Helpers {
  address internal constant _ZERO_ADDRESS = address(0);
  uint256 internal constant _ZERO_VALUE = 0;

  ForTestL1OpUSDCFactory public factory;

  address internal _owner = makeAddr('owner');
  address internal _user = makeAddr('user');
  address internal _usdc = makeAddr('USDC');
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
    factory = new ForTestL1OpUSDCFactory(_usdc, _owner);
    _upgradeManager = address(factory.UPGRADE_MANAGER());

    // Set the bytecode to the implementation addresses
    vm.etch(_l2AdapterImplAddress, _l2AdapterBytecode);
    vm.etch(_l2UsdcImplAddress, _l2UsdcImplementationBytecode);

    // Define the implementation structs info
    _usdcImplInitTxs.push(_usdcInitTx);
    _l2AdapterInitTxs.push(_l2AdapterInitTx);
    _bridgedUsdcImplementation = IUpgradeManager.Implementation(_l2UsdcImplAddress, _usdcImplInitTxs);
    _l2AdapterImplementation = IUpgradeManager.Implementation(_l2AdapterImplAddress, _l2AdapterInitTxs);
  }
}

contract L1OpUSDCFactory_Unit_Constructor is Base {
  event L1AdapterDeployed(address _l1Adapter);

  event UpgradeManagerDeployed(address _upgradeManager);

  /**
   * @notice Test the constructor params are correctly set
   */
  function test_setImmutables() public {
    // Precalculate the addresses
    address _aliasedSelf = AddressAliasHelper.applyL1ToL2Alias(address(factory));
    address _l2Factory = _computeCreateAddress(_aliasedSelf, 0);
    address _l1Adapter = _computeCreateAddress(address(factory), 1);
    address _l2UsdcImplAddress = _computeCreateAddress(_l2Factory, 1);
    address _l2UsdcProxyAddress = _computeCreateAddress(_l2Factory, 2);
    address _l2AdapterImpl = _computeCreateAddress(_l2Factory, 3);
    address _l2AdapterProxy = _computeCreateAddress(_l2Factory, 4);
    address _upgradeManager = _computeCreateAddress(address(factory), 3);

    // Assert
    assertEq(factory.ALIASED_SELF(), _aliasedSelf, 'Invalid aliasedSelf address');
    assertEq(factory.L1_ADAPTER(), _l1Adapter, 'Invalid l1Adapter address');
    assertEq(factory.L2_ADAPTER_IMPLEMENTATION(), _l2AdapterImpl, 'Invalid l2Adapter implementation address');
    assertEq(factory.L2_ADAPTER_PROXY(), _l2AdapterProxy, 'Invalid l2Adapter proxy address');
    assertEq(factory.L2_USDC_PROXY(), _l2UsdcProxyAddress, 'Invalid l2UsdcProxy address');
    assertEq(factory.L2_USDC_IMPLEMENTATION(), _l2UsdcImplAddress, 'Invalid l2UsdcImplementation address');
    assertEq(address(factory.UPGRADE_MANAGER()), _upgradeManager, 'Invalid upgradeManager address');
  }

  /**
   * @notice Check the constructor correctly deploys the L1 adapter
   * @dev We are assuming the L1 adapter correctly sets the immutable vars to compare. Need to do this to check the
   * contract constructor values were properly set.
   */
  function test_deployL1Adapter() public {
    L1OpUSDCBridgeAdapter _l1Adapter = L1OpUSDCBridgeAdapter(factory.L1_ADAPTER());
    assertEq(_l1Adapter.USDC(), _usdc, 'Invalid owner');
    assertEq(_l1Adapter.LINKED_ADAPTER(), factory.L2_ADAPTER_PROXY(), 'Invalid l2Adapter');
    assertEq(address(_l1Adapter.UPGRADE_MANAGER()), address(factory.UPGRADE_MANAGER()), 'Invalid upgradeManager');
    assertEq(_l1Adapter.FACTORY(), address(factory), 'Invalid owner');
  }

  /**
   * @notice Check the `L1AdapterDeployed` event is properly emitted
   */
  function test_emitL1AdapterDeployedEvent() public {
    // Precalculate the L1 adapter address to be emitted
    address _newFactory = _computeCreateAddress(address(this), 2);
    address _l1Adapter = _computeCreateAddress(_newFactory, 1);

    // Expect
    vm.expectEmit(true, true, true, true);
    emit L1AdapterDeployed(_l1Adapter);

    // Execute
    new ForTestL1OpUSDCFactory(_usdc, _owner);
  }

  /**
   * @notice Check the constructor correctly deploys the upgrade manager implementation
   * @dev We are assuming the upgrade manager correctly sets the immutable vars to compare. Need to do this to check the
   * contract constructor values were properly set.
   */
  function test_deployUpgradeManagerImplementation() public {
    IUpgradeManager _upgradeManager = IUpgradeManager(address(factory.UPGRADE_MANAGER()));
    assertEq(_upgradeManager.L1_ADAPTER(), factory.L1_ADAPTER(), 'Invalid l1Adapter');
  }

  /**
   * @notice Check the constructor correctly deploys the upgrade manager proxy
   * @dev We are assuming the upgrade manager correctly sets the immutable vars to compare. Need to do this to check the
   * contract constructor values were properly set.
   */
  function test_deployUpgradeManagerProxy() public {
    /// NOTE: Assuming the upgrade manager correctly initializes the vars to compare. Need to do this to check the
    // contract was properly initialized.
    UpgradeManager _upgradeManager = UpgradeManager(address(factory.UPGRADE_MANAGER()));
    assertEq(_upgradeManager.owner(), _owner, 'Invalid owner');
  }

  /**
   * @notice Check the `UpgradeManagerDeployed` event is properly emitted
   */
  function test_emitUpgradeManagerDeployedEvent() public {
    // Precalculate the upgrade manager address to be emitted
    address _newFactory = _computeCreateAddress(address(this), 2);
    address _upgradeManager = _computeCreateAddress(_newFactory, 3);

    // Expect
    vm.expectEmit(true, true, true, true);
    emit UpgradeManagerDeployed(_upgradeManager);

    // Execute
    new ForTestL1OpUSDCFactory(_usdc, _owner);
  }
}

contract L1OpUSDCFactory_Unit_DeployL2UsdcAndAdapter is Base {
  /**
   * @notice Check the `deployL2UsdcAndAdapter` function reverts if the messenger already has a protocol deployed for it
   */
  function test_revertIfMessengerAlreadyDeployedFor(uint32 _minGasLimit) public {
    // Mock the `isMessengerDeployed` to return true
    factory.forTest_setIsMessengerDeployed(_l1Messenger, true);

    // Execute
    vm.expectRevert(IL1OpUSDCFactory.IL1OpUSDCFactory_MessengerAlreadyDeployed.selector);
    vm.prank(_user);
    factory.deployL2UsdcAndAdapter(_l1Messenger, _minGasLimit);
  }

  /**
   * @notice Check the `deployL2UsdcAndAdapter` function reverts if the caller is not the executor
   */
  function test_revertIfNotExecutor(uint32 _minGasLimit, address _executor) public {
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
    factory.deployL2UsdcAndAdapter(_l1Messenger, _minGasLimit);
  }

  /**
   * @notice Check the `deployL2UsdcAndAdapter` function calls the `messengerDeploymentExecutor` correctly
   */
  function test_callMessengerDeploymentExecutor(uint32 _minGasLimit) public {
    // Mock all the `deployL2UsdcAndAdapter` function calls
    _mockDeployFunctionCalls();

    // Expect the `bridgedUSDCImplementation` to be properly called
    vm.expectCall(_upgradeManager, abi.encodeWithSelector(IUpgradeManager.messengerDeploymentExecutor.selector));

    // Execute
    vm.prank(_user);
    factory.deployL2UsdcAndAdapter(_l1Messenger, _minGasLimit);
  }

  /**
   * @notice Check the `deployL2UsdcAndAdapter` function calls the `bridgedUSDCImplementation` correctly
   */
  function test_callBridgedUSDCImplementation(uint32 _minGasLimit) public {
    // Mock all the `deployL2UsdcAndAdapter` function calls
    _mockDeployFunctionCalls();

    // Expect the `bridgedUSDCImplementation` to be properly called
    vm.expectCall(_upgradeManager, abi.encodeWithSelector(IUpgradeManager.bridgedUSDCImplementation.selector));

    // Execute
    vm.prank(_user);
    factory.deployL2UsdcAndAdapter(_l1Messenger, _minGasLimit);
  }

  /**
   * @notice Check the `deployL2UsdcAndAdapter` function calls the `l2AdapterImplementation` correctly
   */
  function test_callL2AdapterImplementation(uint32 _minGasLimit) public {
    // Mock all the `deployL2UsdcAndAdapter` function calls
    _mockDeployFunctionCalls();

    // Expect the `l2AdapterImplementation` to be properly called
    vm.expectCall(_upgradeManager, abi.encodeWithSelector(IUpgradeManager.l2AdapterImplementation.selector));

    // Execute
    vm.prank(_user);
    factory.deployL2UsdcAndAdapter(_l1Messenger, _minGasLimit);
  }

  function test_callPortal(uint32 _minGasLimit) public {
    // Mock all the `deployL2UsdcAndAdapter` function calls
    _mockDeployFunctionCalls();

    // Expect the `portal` function to be properly called
    vm.expectCall(_l1Messenger, abi.encodeWithSelector(ICrossDomainMessenger.portal.selector));

    // Execute
    vm.prank(_user);
    factory.deployL2UsdcAndAdapter(_l1Messenger, _minGasLimit);
  }

  /**
   * @notice Check the `deployL2UsdcAndAdapter` function calls the `portal` correctly
   */
  function test_callDepositTransaction(uint32 _minGasLimit) public {
    // Get the L2 usdc proxy init code
    bytes memory _usdcProxyCArgs = abi.encode(factory.L2_USDC_IMPLEMENTATION());
    bytes memory _usdcProxyInitCode = bytes.concat(USDC_PROXY_CREATION_CODE, _usdcProxyCArgs);

    // Get the bytecode of the L2 usdc implementation
    bytes memory _l2UsdcImplementationBytecode = _bridgedUsdcImplementation.implementation.code;
    // Get the bytecode of the he L2 adapter
    bytes memory _l2AdapterBytecode = _l2AdapterImplementation.implementation.code;

    // Get the L2 factory init code
    bytes memory _l2FactoryCreationCode = type(L2OpUSDCFactory).creationCode;
    bytes memory _l2FactoryCArgs = abi.encode(
      _usdcProxyInitCode,
      _l2UsdcImplementationBytecode,
      _bridgedUsdcImplementation.initTxs,
      _l2AdapterBytecode,
      _l2AdapterImplementation.initTxs
    );
    bytes memory _l2FactoryInitCode = bytes.concat(_l2FactoryCreationCode, _l2FactoryCArgs);

    // Expect the `depositTransaction` to be properly called
    bool _isCreation = true;
    vm.expectCall(
      _portal,
      abi.encodeWithSelector(
        IOptimismPortal.depositTransaction.selector,
        _ZERO_ADDRESS,
        _ZERO_VALUE,
        _minGasLimit,
        _isCreation,
        _l2FactoryInitCode
      )
    );

    // Mock all the `deployL2UsdcAndAdapter` function calls
    _mockDeployFunctionCalls();

    // Execute
    vm.prank(_user);
    factory.deployL2UsdcAndAdapter(_l1Messenger, _minGasLimit);
  }

  /**
   * @notice Helper function to mock all the function calls that will be made in the `deployL2UsdcAndAdapter` function
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
    vm.mockCall(_l1Messenger, abi.encodeWithSelector(ICrossDomainMessenger.portal.selector), abi.encode(_portal));

    // Mock the call over the `depositTransaction` function on the portal
    vm.mockCall(_portal, abi.encodeWithSelector(IOptimismPortal.depositTransaction.selector), abi.encode(true));
  }
}

contract L1OpUSDCFactory_Unit_PrecalculateCreateAddress is Base {
  /**
   * @notice Check the `precalculateCreateAddress` function returns the correct address for the given deployer and nonce
   */
  function test_precalculateCreateAddress(address _deployer) public {
    vm.assume(vm.getNonce(_deployer) == 0);
    for (uint256 i = 0; i < 127; i++) {
      // Precalculate the address
      address _precalculatedAddress = _computeCreateAddress(_deployer, i);

      // Execute
      vm.prank(_deployer);
      address _newAddress = address(new ForTest_DummyContract());

      // Assert
      assertEq(_newAddress, _precalculatedAddress, 'Invalid precalculated address');
    }
  }
}

/**
 * @notice Dummy contract to be deployed only for testing purposes
 */
contract ForTest_DummyContract {}
