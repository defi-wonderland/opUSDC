// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {L2OpUSDCFactory} from 'contracts/L2OpUSDCFactory.sol';
import {USDC_PROXY_CREATION_CODE} from 'contracts/utils/USDCProxyCreationCode.sol';
import {Test} from 'forge-std/Test.sol';
import {IL2OpUSDCFactory} from 'interfaces/IL2OpUSDCFactory.sol';
import {IOpUSDCBridgeAdapter} from 'interfaces/IOpUSDCBridgeAdapter.sol';
import {ICrossDomainMessenger} from 'interfaces/external/ICrossDomainMessenger.sol';
import {IUSDC} from 'interfaces/external/IUSDC.sol';
import {Helpers} from 'test/utils/Helpers.sol';

contract L2OpUSDCFactoryTest is L2OpUSDCFactory {
  constructor(address _l1Factory) L2OpUSDCFactory(_l1Factory) {}

  function forTest_deployCreate(bytes memory _initCode) public returns (address _newContract, bool _success) {
    (_newContract, _success) = _deployCreate(_initCode);
  }

  function forTest_executeInitTxs(
    address _usdc,
    USDCInitializeData calldata _usdcInitializeData,
    address _l2Adapter,
    bytes[] calldata _initTxs
  ) public {
    _executeInitTxs(_usdc, _usdcInitializeData, _l2Adapter, _initTxs);
  }
}

contract Base is Test, Helpers {
  L2OpUSDCFactoryTest public factory;

  address internal _l2Messenger = 0x4200000000000000000000000000000000000007;
  address internal _l1Factory = makeAddr('l1Factory');

  address internal _messenger = makeAddr('messenger');
  address internal _create2Deployer = makeAddr('create2Deployer');
  address internal _l1Adapter = makeAddr('l1Adapter');
  address internal _l2AdapterOwner = makeAddr('l2AdapterOwner');
  address internal _l2Adapter;

  address internal _dummyContract;
  bytes internal _usdcImplInitCode;

  IL2OpUSDCFactory.USDCInitializeData internal _usdcInitializeData;
  bytes[] internal _emptyInitTxs;
  bytes[] internal _initTxsUsdc;
  bytes[] internal _badInitTxs;

  function setUp() public virtual {
    // Deploy the l2 factory
    vm.prank(_create2Deployer);
    factory = new L2OpUSDCFactoryTest(_l1Factory);

    // Set the initialize data
    _usdcInitializeData = IL2OpUSDCFactory.USDCInitializeData({
      _tokenName: 'USD Coin',
      _tokenSymbol: 'USDC',
      _tokenCurrency: 'USD',
      _tokenDecimals: 6
    });

    // Set the implementations bytecode and init code
    _usdcImplInitCode = type(ForTestDummyContract).creationCode;

    // Set the init txs for the USDC implementation contract (DummyContract)
    bytes memory _initTxOne = abi.encodeWithSignature('returnTrue()');
    bytes memory _initTxTwo = abi.encodeWithSignature('returnFalse()');
    _initTxsUsdc = new bytes[](2);
    _initTxsUsdc[0] = _initTxOne;
    _initTxsUsdc[1] = _initTxTwo;

    // Set the bad init transaction to test when the initialization fails
    bytes memory _badInitTx = abi.encodeWithSignature('nonExistentFunction()');
    _badInitTxs = new bytes[](2);
    _badInitTxs[0] = '';
    _badInitTxs[1] = _badInitTx;
  }
}

contract L2OpUSDCFactory_Unit_Constructor is Base {
  /**
   * @notice Check the immutables are properly set
   */
  function test_setImmutables() public {
    assertEq(factory.L1_FACTORY(), _l1Factory);
  }
}

contract L2OpUSDCFactory_Unit_Deploy is Base {
  event USDCImplementationDeployed(address _l2UsdcImplementation);
  event USDCProxyDeployed(address _l2UsdcProxy);
  event L2AdapterDeployed(address _l2Adapter);
  event ChangeAdminFailed(address _newAdmin);
  event CreateDeploymentFailed();

  /**
   * @notice Check it reverts if the sender is not the L2 messenger
   */
  function test_revertIfSenderNotMessenger(address _sender) public {
    vm.assume(_sender != factory.L2_MESSENGER());
    vm.expectRevert(IL2OpUSDCFactory.IL2OpUSDCFactory_InvalidSender.selector);
    // Execute
    vm.prank(_sender);
    factory.deploy(_l1Adapter, _l2AdapterOwner, _usdcImplInitCode, _usdcInitializeData, _initTxsUsdc);
  }

  /**
   * @notice Check it reverts if the L1 factory is not the xDomain sender
   */
  function test_revertIfL1FactoryNotXDomainSender(address _xDomainSender) public {
    vm.assume(_xDomainSender != factory.L1_FACTORY());

    // Mock the call over `xDomainMessageSender` to return and invalid sender
    vm.mockCall(
      factory.L2_MESSENGER(),
      abi.encodeWithSelector(ICrossDomainMessenger.xDomainMessageSender.selector),
      abi.encode(_xDomainSender)
    );

    // Execute
    vm.prank(factory.L2_MESSENGER());
    vm.expectRevert(IL2OpUSDCFactory.IL2OpUSDCFactory_InvalidSender.selector);
    factory.deploy(_l1Adapter, _l2AdapterOwner, _usdcImplInitCode, _usdcInitializeData, _initTxsUsdc);
  }

  /**
   * @notice Check the deployment of the USDC implementation and proxy is properly done by checking the emitted event
   * and the 'upgradeTo' call to the proxy
   */
  function test_deployUsdcImplementation() public {
    // Get the usdc implementation address
    uint256 _usdcImplDeploymentNonce = vm.getNonce(address(factory));
    address _usdcImplementation = _precalculateCreateAddress(address(factory), _usdcImplDeploymentNonce);

    // Mock the call over `xDomainMessageSender` to return the L1 factory address
    vm.mockCall(
      factory.L2_MESSENGER(),
      abi.encodeWithSelector(ICrossDomainMessenger.xDomainMessageSender.selector),
      abi.encode(factory.L1_FACTORY())
    );

    // Expect the USDC deployment event to be properly emitted
    vm.expectEmit(true, true, true, true);
    emit USDCImplementationDeployed(_usdcImplementation);

    // Execute
    vm.prank(_l2Messenger);
    factory.deploy(_l1Adapter, _l2AdapterOwner, _usdcImplInitCode, _usdcInitializeData, _emptyInitTxs);

    // Assert the USDC implementation was deployed
    assertGt(_usdcImplementation.code.length, 0, 'USDC implementation was not deployed');
    assertTrue(ForTestDummyContract(_usdcImplementation).returnTrue(), 'USDC implementation was not properly deployed');
  }

  /**
   * @notice Check the deployment of the L2 adapter implementation and proxy is properly done by checking the emitted
   * event and the implementation length
   * @dev Assuming the USDC proxy correctly sets the implementation address to check it was properly deployed
   */
  function test_deployUsdcProxy() public {
    // Calculate the usdc implementation address
    uint256 _usdcImplDeploymentNonce = vm.getNonce(address(factory));
    address _usdcImpl = _precalculateCreateAddress(address(factory), _usdcImplDeploymentNonce);

    // Calculate the usdc proxy address
    uint256 _usdcProxyDeploymentNonce = vm.getNonce(address(factory)) + 1;
    address _usdcProxy = _precalculateCreateAddress(address(factory), _usdcProxyDeploymentNonce);

    // Mock the call over `xDomainMessageSender` to return the L1 factory address
    vm.mockCall(
      factory.L2_MESSENGER(),
      abi.encodeWithSelector(ICrossDomainMessenger.xDomainMessageSender.selector),
      abi.encode(factory.L1_FACTORY())
    );

    // Expect the USDC proxy deployment event to be properly emitted
    vm.expectEmit(true, true, true, true);
    emit USDCProxyDeployed(_usdcProxy);

    // Execute
    vm.prank(_l2Messenger);
    factory.deploy(_l1Adapter, _l2AdapterOwner, _usdcImplInitCode, _usdcInitializeData, _emptyInitTxs);

    // Assert the USDC proxy was deployed
    assertGt(_usdcProxy.code.length, 0, 'USDC proxy was not deployed');
    assertEq(IUSDC(_usdcProxy).implementation(), _usdcImpl, 'USDC implementation was not set');
  }

  /**
   * @notice Check the deployment of the L2 adapter implementation and proxy is properly done by checking the address
   * on the emitted, the code length of the contract and the constructor values were properly set
   * @dev Assuming the adapter correctly sets the immutables to check the constructor values were properly set
   */
  function test_deployAdapter() public {
    // Get the USDC proxy address
    uint256 _usdcProxyDeploymentNonce = vm.getNonce(address(factory)) + 1;
    address _usdcProxy = _precalculateCreateAddress(address(factory), _usdcProxyDeploymentNonce);

    // Get the adapter address
    uint256 _adapterDeploymentNonce = vm.getNonce(address(factory)) + 2;
    _l2Adapter = _precalculateCreateAddress(address(factory), _adapterDeploymentNonce);

    // Mock the call over `xDomainMessageSender` to return the L1 factory address
    vm.mockCall(
      factory.L2_MESSENGER(),
      abi.encodeWithSelector(ICrossDomainMessenger.xDomainMessageSender.selector),
      abi.encode(factory.L1_FACTORY())
    );

    // Expect the adapter deployment event to be properly emitted
    vm.expectEmit(true, true, true, true);
    emit L2AdapterDeployed(_l2Adapter);

    // Execute
    vm.prank(_l2Messenger);
    factory.deploy(_l1Adapter, _l2AdapterOwner, _usdcImplInitCode, _usdcInitializeData, _emptyInitTxs);

    // Assert the adapter was deployed
    assertGt(_l2Adapter.code.length, 0, 'Adapter was not deployed');
    // Check the constructor values were properly set
    assertEq(IOpUSDCBridgeAdapter(_l2Adapter).USDC(), _usdcProxy, 'USDC address was not set');
    assertEq(IOpUSDCBridgeAdapter(_l2Adapter).MESSENGER(), _l2Messenger, 'Messenger address was not set');
    assertEq(IOpUSDCBridgeAdapter(_l2Adapter).LINKED_ADAPTER(), _l1Adapter, 'Linked adapter address was not set');
    assertEq(Ownable(_l2Adapter).owner(), _l2AdapterOwner, 'Owner address was not set');
  }

  /**
   * @notice Check it emits a failure event if the USDC implementation deployment fail
   */
  function test_emitOnFailedUsdcImplementationDeployment() public {
    // Deploy the USDC implementation to the same address as the factory to make it fail
    uint256 _usdcImplDeploymentNonce = vm.getNonce(address(factory));
    address _usdcImplementation = _precalculateCreateAddress(address(factory), _usdcImplDeploymentNonce);

    // Set bytecode to the address where the USDC implementation will be deployed to make it fail
    vm.etch(_usdcImplementation, _usdcImplInitCode);

    // Mock the call over `xDomainMessageSender` to return the L1 factory address
    vm.mockCall(
      factory.L2_MESSENGER(),
      abi.encodeWithSelector(ICrossDomainMessenger.xDomainMessageSender.selector),
      abi.encode(factory.L1_FACTORY())
    );

    // Expect the tx to emit the failure
    vm.expectEmit(true, true, true, true);
    emit CreateDeploymentFailed();

    // Execute
    vm.prank(_l2Messenger);
    factory.deploy(_l1Adapter, _l2AdapterOwner, _usdcImplInitCode, _usdcInitializeData, _emptyInitTxs);
  }

  /**
   * @notice Check it emits a failure event if the USDC proxy deployment fail
   */
  function test_emitOnFailedUsdcProxyDeployment() public {
    // Calculate the usdc proxy address
    uint256 _usdcProxyDeploymentNonce = vm.getNonce(address(factory)) + 1;
    address _usdcProxy = _precalculateCreateAddress(address(factory), _usdcProxyDeploymentNonce);

    // Set bytecode to the address where the USDC will be deployed to make it fail
    vm.etch(_usdcProxy, _usdcImplInitCode);

    // Mock the call over `xDomainMessageSender` to return the L1 factory address
    vm.mockCall(
      factory.L2_MESSENGER(),
      abi.encodeWithSelector(ICrossDomainMessenger.xDomainMessageSender.selector),
      abi.encode(factory.L1_FACTORY())
    );

    // Expect the tx to emit the failure
    vm.expectEmit(true, true, true, true);
    emit CreateDeploymentFailed();

    // Execute
    vm.prank(_l2Messenger);
    factory.deploy(_l1Adapter, _l2AdapterOwner, _usdcImplInitCode, _usdcInitializeData, _emptyInitTxs);
  }

  /**
   * @notice Check it emits a failure event if the adapter deployment fail
   */
  function test_emitOnFailedAdapterDeployment() public {
    // Get the adapter address
    uint256 _adapterDeploymentNonce = vm.getNonce(address(factory)) + 2;
    address _l2Adapter = _precalculateCreateAddress(address(factory), _adapterDeploymentNonce);

    // Set bytecode to the address where the L2 Adapter will be deployed
    vm.etch(_l2Adapter, _usdcImplInitCode);

    // Mock the call over `xDomainMessageSender` to return the L1 factory address
    vm.mockCall(
      factory.L2_MESSENGER(),
      abi.encodeWithSelector(ICrossDomainMessenger.xDomainMessageSender.selector),
      abi.encode(factory.L1_FACTORY())
    );

    // Expect the tx to emit the failure
    vm.expectEmit(true, true, true, true);
    emit CreateDeploymentFailed();
    // Execute
    vm.prank(_l2Messenger);
    factory.deploy(_l1Adapter, _l2AdapterOwner, _usdcImplInitCode, _usdcInitializeData, _emptyInitTxs);
  }

  /**
   * @notice Check the `changeAdmin` function is called on the USDC proxy
   */
  function test_callChangeAdmin() public {
    // Get the usdc proxy address
    uint256 _usdcProxyDeploymentNonce = vm.getNonce(address(factory)) + 1;
    address _usdcProxy = _precalculateCreateAddress(address(factory), _usdcProxyDeploymentNonce);

    // Get the adapter address
    uint256 _adapterDeploymentNonce = vm.getNonce(address(factory)) + 2;
    address _l2Adapter = _precalculateCreateAddress(address(factory), _adapterDeploymentNonce);
    address _fallbackProxyAdmin = _precalculateCreateAddress(address(_l2Adapter), 1);

    // Mock the call over `xDomainMessageSender` to return the L1 factory address
    vm.mockCall(
      _l2Messenger, abi.encodeWithSelector(ICrossDomainMessenger.xDomainMessageSender.selector), abi.encode(_l1Factory)
    );

    // Expect the call over 'changeAdmin' function
    vm.expectCall(_usdcProxy, abi.encodeWithSelector(IUSDC.changeAdmin.selector, address(_fallbackProxyAdmin)));

    // Execute
    vm.prank(_l2Messenger);
    factory.deploy(_l1Adapter, _l2AdapterOwner, _usdcImplInitCode, _usdcInitializeData, _emptyInitTxs);
  }

  /**
   * @notice Check the `changeAdmin` emits event if it fails
   */
  function test_emitsEventIfChangeAdminFails() public {
    // Get the usdc proxy address
    uint256 _usdcProxyDeploymentNonce = vm.getNonce(address(factory)) + 1;
    address _usdcProxy = _precalculateCreateAddress(address(factory), _usdcProxyDeploymentNonce);

    // Get the adapter address
    uint256 _adapterDeploymentNonce = vm.getNonce(address(factory)) + 2;
    address _l2Adapter = _precalculateCreateAddress(address(factory), _adapterDeploymentNonce);
    address _fallbackProxyAdmin = _precalculateCreateAddress(address(_l2Adapter), 1);

    // Mock the call over `xDomainMessageSender` to return the L1 factory address
    vm.mockCall(
      _l2Messenger, abi.encodeWithSelector(ICrossDomainMessenger.xDomainMessageSender.selector), abi.encode(_l1Factory)
    );

    // Expect the call over 'changeAdmin' function
    vm.mockCallRevert(
      _usdcProxy, abi.encodeWithSelector(IUSDC.changeAdmin.selector, address(_fallbackProxyAdmin)), abi.encode()
    );

    vm.expectEmit(true, true, true, true);
    emit ChangeAdminFailed(_fallbackProxyAdmin);

    // Execute
    vm.prank(_l2Messenger);
    factory.deploy(_l1Adapter, _l2AdapterOwner, _usdcImplInitCode, _usdcInitializeData, _emptyInitTxs);
  }

  /**
   * @notice Check init txs are properly executed over the USDC implementation and proxy
   */
  function test_executeUsdcImplInitTxs() public {
    // Deploy the USDC implementation to the same address as the factory to make it fail
    uint256 _usdcImplDeploymentNonce = vm.getNonce(address(factory));
    address _usdcImplementation = _precalculateCreateAddress(address(factory), _usdcImplDeploymentNonce);

    // Mock the call over `xDomainMessageSender` to return the L1 factory address
    vm.mockCall(
      _l2Messenger, abi.encodeWithSelector(ICrossDomainMessenger.xDomainMessageSender.selector), abi.encode(_l1Factory)
    );

    // Expect the init txs to be called
    vm.expectCall(_usdcImplementation, _initTxsUsdc[0]);

    // Execute
    vm.prank(_l2Messenger);
    factory.deploy(_l1Adapter, _l2AdapterOwner, _usdcImplInitCode, _usdcInitializeData, _initTxsUsdc);
  }

  /**
   * @notice Check init txs are properly executed over the L2 adapter implementation and proxy, and that the
   * `changeAdmin` function is called on it too.
   */
  function test_executeUsdcProxyInitTxs() public {
    // Get the usdc proxy address
    uint256 _usdcProxyDeploymentNonce = vm.getNonce(address(factory)) + 1;
    address _usdcProxy = _precalculateCreateAddress(address(factory), _usdcProxyDeploymentNonce);

    // Mock the call over `xDomainMessageSender` to return the L1 factory address
    vm.mockCall(
      _l2Messenger, abi.encodeWithSelector(ICrossDomainMessenger.xDomainMessageSender.selector), abi.encode(_l1Factory)
    );

    // Expect the init txs to be called
    vm.expectCall(_usdcProxy, _initTxsUsdc[0]);
    vm.expectCall(_usdcProxy, _initTxsUsdc[1]);

    // Execute
    vm.prank(_l2Messenger);
    factory.deploy(_l1Adapter, _l2AdapterOwner, _usdcImplInitCode, _usdcInitializeData, _initTxsUsdc);
  }
}

contract L2OpUSDCFactory_Unit_ExecuteInitTxs is Base {
  event InitializationFailed(uint256 _index);
  event ConfigureMinterFailed(address _minter);
  event UpdateMasterMinterFailed(address _newMasterMinter);
  event TransferOwnershipFailed(address _newOwner);
  /**
   * @notice Check `initialize()` is properly called
   */

  function test_callInitialize() public {
    // Mock the call over the functions
    _mockExecuteTxsCalls();

    // Expect `initialize` to be properly called
    vm.expectCall(
      _dummyContract,
      abi.encodeWithSelector(
        IUSDC.initialize.selector,
        _usdcInitializeData._tokenName,
        _usdcInitializeData._tokenSymbol,
        _usdcInitializeData._tokenCurrency,
        _usdcInitializeData._tokenDecimals,
        address(factory),
        _l2Adapter,
        _l2Adapter,
        address(factory)
      )
    );

    // Execute
    factory.forTest_executeInitTxs(_dummyContract, _usdcInitializeData, _l2Adapter, _initTxsUsdc);
  }

  /**
   * @notice Check `initialize()` emits a failure event
   */
  function test_emitsEventIfInitializeFails() public {
    // Mock the call over the functions
    _mockExecuteTxsCalls();

    // Expect `initialize` to be properly called
    vm.mockCallRevert(
      _dummyContract,
      abi.encodeWithSelector(
        IUSDC.initialize.selector,
        _usdcInitializeData._tokenName,
        _usdcInitializeData._tokenSymbol,
        _usdcInitializeData._tokenCurrency,
        _usdcInitializeData._tokenDecimals,
        address(factory),
        _l2Adapter,
        _l2Adapter,
        address(factory)
      ),
      abi.encode()
    );

    vm.expectEmit(true, true, true, true);
    emit InitializationFailed(0);

    // Execute
    factory.forTest_executeInitTxs(_dummyContract, _usdcInitializeData, _l2Adapter, _initTxsUsdc);
  }

  /**
   * @notice Check `configureMinter()` is properly called
   */
  function test_callConfigureMinter() public {
    // Mock the call over the functions
    _mockExecuteTxsCalls();

    // Expect `configureMinter` to be properly called
    // solhint-disable-next-line max-line-length
    vm.expectCall(_dummyContract, abi.encodeWithSelector(IUSDC.configureMinter.selector, _l2Adapter, type(uint256).max));

    // Execute
    factory.forTest_executeInitTxs(_dummyContract, _usdcInitializeData, _l2Adapter, _initTxsUsdc);
  }

  /**
   * @notice Check `configureMinter()` emits a failure event
   */
  function test_emitsEventIfConfigureMinterFails() public {
    // Mock the call over the functions
    _mockExecuteTxsCalls();

    // Expect `configureMinter` to be properly called
    // solhint-disable-next-line max-line-length
    vm.mockCallRevert(
      _dummyContract,
      abi.encodeWithSelector(IUSDC.configureMinter.selector, _l2Adapter, type(uint256).max),
      abi.encode()
    );
    vm.expectEmit(true, true, true, true);
    emit ConfigureMinterFailed(_l2Adapter);

    // Execute
    factory.forTest_executeInitTxs(_dummyContract, _usdcInitializeData, _l2Adapter, _initTxsUsdc);
  }

  /**
   * @notice Check `updateMasterMinter()` is properly called
   */
  function test_callUpdateMasterMinter() public {
    // Mock the call over the functions
    _mockExecuteTxsCalls();

    // Expect `updateMasterMinter` to be properly called
    vm.expectCall(_dummyContract, abi.encodeWithSelector(IUSDC.updateMasterMinter.selector, _l2Adapter));

    // Execute
    factory.forTest_executeInitTxs(_dummyContract, _usdcInitializeData, _l2Adapter, _initTxsUsdc);
  }

  /**
   * @notice Check `updateMasterMinter()` emits a failure event
   */
  function test_emitsEventIfUpdateMasterMinterFails() public {
    // Mock the call over the functions
    _mockExecuteTxsCalls();

    // Expect `updateMasterMinter` to be properly called
    vm.mockCallRevert(
      _dummyContract, abi.encodeWithSelector(IUSDC.updateMasterMinter.selector, _l2Adapter), abi.encode()
    );
    vm.expectEmit(true, true, true, true);
    emit UpdateMasterMinterFailed(_l2Adapter);

    // Execute
    factory.forTest_executeInitTxs(_dummyContract, _usdcInitializeData, _l2Adapter, _initTxsUsdc);
  }

  /**
   * @notice Check `transferOwnership()` is properly called
   */
  function test_callTransferOwnership() public {
    // Mock the call over the functions
    _mockExecuteTxsCalls();

    // Expect `transferOwnership` to be properly called
    vm.expectCall(_dummyContract, abi.encodeWithSelector(IUSDC.transferOwnership.selector, _l2Adapter));

    // Execute
    factory.forTest_executeInitTxs(_dummyContract, _usdcInitializeData, _l2Adapter, _initTxsUsdc);
  }

  /**
   * @notice Check `transferOwnership()` emits a failure event
   */
  function test_emitsEventIfTransferOwnershipFails() public {
    // Mock the call over the functions
    _mockExecuteTxsCalls();

    // Expect `transferOwnership` to be properly called
    vm.mockCallRevert(
      _dummyContract, abi.encodeWithSelector(IUSDC.transferOwnership.selector, _l2Adapter), abi.encode()
    );
    vm.expectEmit(true, true, true, true);
    emit TransferOwnershipFailed(_l2Adapter);

    // Execute
    factory.forTest_executeInitTxs(_dummyContract, _usdcInitializeData, _l2Adapter, _initTxsUsdc);
  }

  /**
   * @notice Check the execution of the initialization transactions over a target contract
   */
  function test_executeInitTxsArray(address _l2Adapter) public {
    _mockExecuteTxsCalls();

    // Mock the call to the target contract
    _mockAndExpect(_dummyContract, _initTxsUsdc[0], '');
    _mockAndExpect(_dummyContract, _initTxsUsdc[1], '');

    // Execute the initialization transactions
    factory.forTest_executeInitTxs(_dummyContract, _usdcInitializeData, _l2Adapter, _initTxsUsdc);
  }

  /**
   * @notice Check it emits a failure if the initialization transactions fail
   */
  function test_revertIfInitTxsOnArrayFail() public {
    _mockExecuteTxsCalls();

    vm.mockCallRevert(_dummyContract, _badInitTxs[0], '');
    vm.mockCallRevert(_dummyContract, _badInitTxs[1], '');

    vm.expectEmit(true, true, true, true);
    emit InitializationFailed(1);
    // Execute
    factory.forTest_executeInitTxs(_dummyContract, _usdcInitializeData, _l2Adapter, _badInitTxs);
  }

  /**
   * @notice Check it emits a failure if the initialization transactions fail
   */
  function test_revertIfInitTxsOnArrayDifferentIndexFail() public {
    _mockExecuteTxsCalls();

    vm.mockCall(_dummyContract, _badInitTxs[0], abi.encode());
    vm.mockCallRevert(_dummyContract, _badInitTxs[1], '');

    vm.expectEmit(true, true, true, true);
    emit InitializationFailed(2);
    // Execute
    factory.forTest_executeInitTxs(_dummyContract, _usdcInitializeData, _l2Adapter, _badInitTxs);
  }

  function _mockExecuteTxsCalls() internal {
    // Mock call over `initialize()` function
    vm.mockCall(_dummyContract, abi.encodeWithSelector(IUSDC.initialize.selector), '');

    // Mock the call over `configureMinter()` function
    vm.mockCall(_dummyContract, abi.encodeWithSelector(IUSDC.configureMinter.selector), abi.encode(true));

    // Mock the call over `updateMasterMinter()` function
    vm.mockCall(_dummyContract, abi.encodeWithSelector(IUSDC.updateMasterMinter.selector), '');

    // Mock the call over `transferOwnership()` function
    vm.mockCall(_dummyContract, abi.encodeWithSelector(IUSDC.transferOwnership.selector), '');
  }
}

contract L2OpUSDCFactory_Unit_DeployCreate is Base {
  event CreateDeploymentFailed();

  /**
   * @notice Check the deployment of a contract using the `CREATE2` opcode is properly done to the expected addrtess
   */
  function test_deployCreate() public {
    // Get the init code with the USDC proxy creation code plus the USDC implementation address
    bytes memory _initCode = bytes.concat(USDC_PROXY_CREATION_CODE, abi.encode(address(factory)));

    // Precalculate the address of the contract that will be deployed with the current factory's nonce
    uint256 _deploymentNonce = vm.getNonce(address(factory));
    address _expectedAddress = _precalculateCreateAddress(address(factory), _deploymentNonce);

    // Execute
    (address _newContract, bool _success) = factory.forTest_deployCreate(_initCode);

    // Assert the deployed was deployed at the correct address and contract has code
    assertEq(_newContract, _expectedAddress);
    assertGt(_newContract.code.length, 0);
    assertTrue(_success);
  }

  /**
   * @notice Check it reverts if the deployment fails
   */
  function test_revertIfDeploymentFailed() public {
    // Create a bad format for the init code to make the deployment revert
    bytes memory _badInitCode = '0x0000405060';

    // Expect the `CreateDeploymentFailed` event to be emitted
    vm.expectEmit(true, true, true, true);
    emit CreateDeploymentFailed();

    // Execute
    (, bool _success) = factory.forTest_deployCreate(_badInitCode);

    // Assert the deployment failed
    assertFalse(_success);
  }
}

/**
 * @notice Dummy contract used only for testing purposes
 * @dev Need to create a dummy contract and get its bytecode because you can't mock a call over a contract that's not
 * deployed yet, so the unique alternative is to call the contract properly.
 */
contract ForTestDummyContract {
  constructor() {}

  function initialize(
    string memory _tokenName,
    string memory _tokenSymbol,
    string memory _tokenCurrency,
    uint8 _tokenDecimals,
    address _newMasterMinter,
    address _newPauser,
    address _newBlacklister,
    address _newOwner
  ) external {}

  function configureMinter(address, uint256) external returns (bool) {}

  function updateMasterMinter(address) external {}

  function transferOwnership(address) external {}

  function returnTrue() public pure returns (bool) {
    return true;
  }

  function returnFalse() public pure returns (bool) {
    return true;
  }
}
