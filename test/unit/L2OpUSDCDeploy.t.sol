// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {L2OpUSDCDeploy} from 'contracts/L2OpUSDCDeploy.sol';
import {USDC_PROXY_CREATION_CODE} from 'contracts/utils/USDCProxyCreationCode.sol';
import {Test} from 'forge-std/Test.sol';
import {IL2OpUSDCDeploy} from 'interfaces/IL2OpUSDCDeploy.sol';
import {IOpUSDCBridgeAdapter} from 'interfaces/IOpUSDCBridgeAdapter.sol';
import {IUSDC} from 'interfaces/external/IUSDC.sol';
import {Helpers} from 'test/utils/Helpers.sol';

contract L2OpUSDCDeployForTest is L2OpUSDCDeploy {
  constructor(
    address _l1Adapter,
    address _l2AdapterOwner,
    bytes memory _usdcImplementationInitCode,
    USDCInitializeData memory _usdcInitializeData,
    bytes[] memory _usdcInitTxs
  ) L2OpUSDCDeploy(_l1Adapter, _l2AdapterOwner, _usdcImplementationInitCode, _usdcInitializeData, _usdcInitTxs) {}

  function forTest_deployCreate(bytes memory _initCode) public returns (address _newContract) {
    _newContract = _deployCreate(_initCode);
  }

  function forTest_executeInitTxs(
    address _usdc,
    USDCInitializeData memory _usdcInitializeData,
    address _l2Adapter,
    bytes[] memory _initTxs
  ) public {
    _executeInitTxs(_usdc, _usdcInitializeData, _l2Adapter, _initTxs);
  }
}

contract Base is Test, Helpers {
  L2OpUSDCDeployForTest public factory;

  address internal _l2Messenger = 0x4200000000000000000000000000000000000007;
  address internal _l1Factory = makeAddr('l1Factory');
  address internal _messenger = makeAddr('messenger');
  address internal _create2Deployer = makeAddr('create2Deployer');
  address internal _l1Adapter = makeAddr('l1Adapter');
  address internal _l2AdapterOwner = makeAddr('l2AdapterOwner');
  uint256 internal _usdcImplDeploymentNonce = 1;
  uint256 internal _usdcProxyDeploymentNonce = 2;
  uint256 internal _l2AdapterDeploymentNonce = 3;

  address internal _dummyContract;
  bytes internal _usdcImplInitCode;

  IL2OpUSDCDeploy.USDCInitializeData internal _usdcInitializeData;
  bytes[] internal _emptyInitTxs;
  bytes[] internal _initTxsUsdc;
  bytes[] internal _badInitTxs;

  function setUp() public virtual {
    // Precalculate the factory address. The real create 2 deployer will do it through `CREATE2`, but we'll use `CREATE`
    // just for scope of the unit tests
    uint256 _deployerNonce = vm.getNonce(_create2Deployer);
    factory = L2OpUSDCDeployForTest(_precalculateCreateAddress(_create2Deployer, _deployerNonce));

    // Set the implementations bytecode and init code
    _usdcImplInitCode = type(ForTestDummyContract).creationCode;

    // Set the initialize data
    _usdcInitializeData = IL2OpUSDCDeploy.USDCInitializeData({
      tokenName: 'USD Coin',
      tokenSymbol: 'USDC',
      tokenCurrency: 'USD',
      tokenDecimals: 6
    });

    // Set the init txs for the USDC implementation contract (DummyContract)
    bytes memory _initTxOne = abi.encodeWithSignature('returnTrue()');
    bytes memory _initTxTwo = abi.encodeWithSignature('returnFalse()');
    bytes memory _initTxThree = abi.encodeWithSignature('returnOne()');
    _initTxsUsdc = new bytes[](3);
    _initTxsUsdc[0] = _initTxOne;
    _initTxsUsdc[1] = _initTxTwo;
    _initTxsUsdc[2] = _initTxThree;

    // Set the bad init transaction to test when the initialization fails
    bytes memory _badInitTx = abi.encodeWithSignature('nonExistentFunction()');
    _badInitTxs = new bytes[](2);
    _badInitTxs[0] = '';
    _badInitTxs[1] = _badInitTx;
  }
}

contract L2OpUSDCDeploy_Unit_Constructor is Base {
  event USDCImplementationDeployed(address _l2UsdcImplementation);
  event USDCProxyDeployed(address _l2UsdcProxy);
  event L2AdapterDeployed(address _l2Adapter);

  /**
   * @notice Check the deployment of the USDC implementation and proxy is properly done by checking the emitted event
   * and the 'upgradeTo' call to the proxy
   */
  function test_deployUsdcImplementation() public {
    // Calculate the usdc implementation address
    address _usdcImplementation = _precalculateCreateAddress(address(factory), _usdcImplDeploymentNonce);

    // Expect the USDC deployment event to be properly emitted
    vm.expectEmit(true, true, true, true);
    emit USDCImplementationDeployed(_usdcImplementation);

    // Execute
    vm.prank(_create2Deployer);
    new L2OpUSDCDeploy(_l1Adapter, _l2AdapterOwner, _usdcImplInitCode, _usdcInitializeData, _emptyInitTxs);

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
    address _usdcImplementation = _precalculateCreateAddress(address(factory), _usdcImplDeploymentNonce);

    // Calculate the usdc proxy address
    address _usdcProxy = _precalculateCreateAddress(address(factory), _usdcProxyDeploymentNonce);

    // Expect the USDC proxy deployment event to be properly emitted
    vm.expectEmit(true, true, true, true);
    emit USDCProxyDeployed(_usdcProxy);

    // Execute
    vm.prank(_create2Deployer);
    new L2OpUSDCDeploy(_l1Adapter, _l2AdapterOwner, _usdcImplInitCode, _usdcInitializeData, _emptyInitTxs);

    // Assert the USDC proxy was deployed
    assertGt(_usdcProxy.code.length, 0, 'USDC proxy was not deployed');
    assertEq(IUSDC(_usdcProxy).implementation(), _usdcImplementation, 'USDC implementation was not set');
  }

  /**
   * @notice Check the deployment of the L2 adapter implementation and proxy is properly done by checking the address
   * on the emitted, the code length of the contract and the constructor values were properly set
   * @dev Assuming the adapter correctly sets the immutables to check the constructor values were properly set
   */
  function test_deployAdapter() public {
    // Calculate the usdc proxy address
    address _usdcProxy = _precalculateCreateAddress(address(factory), _usdcProxyDeploymentNonce);

    // Calculate the l2 adapter address
    address _l2Adapter = _precalculateCreateAddress(address(factory), _l2AdapterDeploymentNonce);

    // Expect the adapter deployment event to be properly emitted
    vm.expectEmit(true, true, true, true);
    emit L2AdapterDeployed(_l2Adapter);

    // Execute
    vm.prank(_create2Deployer);
    new L2OpUSDCDeploy(_l1Adapter, _l2AdapterOwner, _usdcImplInitCode, _usdcInitializeData, _emptyInitTxs);

    // Assert the adapter was deployed
    assertGt(_l2Adapter.code.length, 0, 'L2 adapter was not deployed');
    // Check the constructor values were properly passed
    assertEq(IOpUSDCBridgeAdapter(_l2Adapter).USDC(), _usdcProxy, 'USDC proxy was not set');
    assertEq(IOpUSDCBridgeAdapter(_l2Adapter).MESSENGER(), _l2Messenger, 'L2 messenger was not set');
    assertEq(IOpUSDCBridgeAdapter(_l2Adapter).LINKED_ADAPTER(), _l1Adapter, 'L1 factory was not set');
    assertEq(Ownable(_l2Adapter).owner(), _l2AdapterOwner, 'L2 adapter owner was not set');
  }

  /**
   * @notice Check the `changeAdmin` function is called on the USDC proxy with the proper fallback proxy admin address
   */
  function test_callChangeAdminWithFallbackProxy() public {
    // Calculate the usdc proxy address
    address _usdcProxy = _precalculateCreateAddress(address(factory), _usdcProxyDeploymentNonce);

    // Calculate the l2 adapter address
    address _l2Adapter = _precalculateCreateAddress(address(factory), _l2AdapterDeploymentNonce);

    // Calculate the fallback proxy admin address
    uint256 _fallbackProxyAdminNonce = 1;
    address _fallbackProxyAdmin = _precalculateCreateAddress(_l2Adapter, _fallbackProxyAdminNonce);

    // Expect the call over 'changeAdmin' function
    vm.expectCall(_usdcProxy, abi.encodeWithSelector(IUSDC.changeAdmin.selector, _fallbackProxyAdmin));

    // Execute
    vm.prank(_create2Deployer);
    new L2OpUSDCDeploy(_l1Adapter, _l2AdapterOwner, _usdcImplInitCode, _usdcInitializeData, _emptyInitTxs);
  }

  /**
   * @notice Check init txs are properly executed over the USDC implementation and proxy
   */
  function test_executeUsdcImplInitTxs() public {
    // Calculate the usdc implementation address
    address _usdcImplementation = _precalculateCreateAddress(address(factory), _usdcImplDeploymentNonce);

    // Expect the init txs to be called
    vm.expectCall(_usdcImplementation, _initTxsUsdc[0]);
    vm.expectCall(_usdcImplementation, _initTxsUsdc[1]);

    // Execute
    vm.prank(_create2Deployer);
    new L2OpUSDCDeploy(_l1Adapter, _l2AdapterOwner, _usdcImplInitCode, _usdcInitializeData, _initTxsUsdc);
  }

  /**
   * @notice Check init txs are properly executed over the L2 adapter implementation and proxy, and that the
   * `changeAdmin` function is called on it too.
   */
  function test_executeUsdcProxyInitTxs() public {
    // Calculate the usdc proxy address
    address _usdcProxy = _precalculateCreateAddress(address(factory), _usdcProxyDeploymentNonce);

    // Expect the init txs to be called
    vm.expectCall(_usdcProxy, _initTxsUsdc[0]);
    vm.expectCall(_usdcProxy, _initTxsUsdc[1]);

    // Execute
    vm.prank(_create2Deployer);
    new L2OpUSDCDeploy(_l1Adapter, _l2AdapterOwner, _usdcImplInitCode, _usdcInitializeData, _initTxsUsdc);
  }
}

contract L2OpUSDCDeploy_Unit_ExecuteInitTxs is Base {
  /**
   * @notice Deploy the factory to test the internal function
   */
  function setUp() public override {
    super.setUp();

    vm.prank(_create2Deployer);
    new L2OpUSDCDeployForTest(_l1Adapter, _l2AdapterOwner, _usdcImplInitCode, _usdcInitializeData, _emptyInitTxs);
  }

  /**
   * @notice Check `initialize()` is properly called
   */
  function test_callInitialize(address _l2Adapter) public {
    // Mock the call over the functions
    _mockExecuteTxsCalls();

    // Expect `initialize` to be properly called
    vm.expectCall(
      address(factory),
      abi.encodeWithSelector(
        IUSDC.initialize.selector,
        _usdcInitializeData.tokenName,
        _usdcInitializeData.tokenSymbol,
        _usdcInitializeData.tokenCurrency,
        _usdcInitializeData.tokenDecimals,
        address(factory),
        _l2Adapter,
        _l2Adapter,
        address(factory)
      )
    );

    // Execute
    factory.forTest_executeInitTxs(address(factory), _usdcInitializeData, _l2Adapter, _emptyInitTxs);
  }

  /**
   * @notice Check `configureMinter()` is properly called
   */
  function test_callConfigureMinter(address _l2Adapter) public {
    // Mock the call over the functions
    _mockExecuteTxsCalls();

    // Expect `configureMinter` to be properly called
    // solhint-disable-next-line max-line-length
    vm.expectCall(
      address(factory), abi.encodeWithSelector(IUSDC.configureMinter.selector, _l2Adapter, type(uint256).max)
    );

    // Execute
    factory.forTest_executeInitTxs(address(factory), _usdcInitializeData, _l2Adapter, _emptyInitTxs);
  }

  /**
   * @notice Check `updateMasterMinter()` is properly called
   */
  function test_callUpdateMasterMinter(address _l2Adapter) public {
    // Mock the call over the functions
    _mockExecuteTxsCalls();

    // Expect `updateMasterMinter` to be properly called
    vm.expectCall(address(factory), abi.encodeWithSelector(IUSDC.updateMasterMinter.selector, _l2Adapter));

    // Execute
    factory.forTest_executeInitTxs(address(factory), _usdcInitializeData, _l2Adapter, _emptyInitTxs);
  }

  /**
   * @notice Check `transferOwnership()` is properly called
   */
  function test_callTransferOwnership(address _l2Adapter) public {
    // Mock the call over the functions
    _mockExecuteTxsCalls();

    // Expect `transferOwnership` to be properly called
    vm.expectCall(address(factory), abi.encodeWithSelector(IUSDC.transferOwnership.selector, _l2Adapter));

    // Execute
    factory.forTest_executeInitTxs(address(factory), _usdcInitializeData, _l2Adapter, _emptyInitTxs);
  }

  /**
   * @notice Check the execution of the initialization transactions over a target contract
   */
  function test_executeInitTxsArray(address _l2Adapter) public {
    _mockExecuteTxsCalls();

    // Mock the call to the target contract
    _mockAndExpect(address(factory), _initTxsUsdc[0], '');
    _mockAndExpect(address(factory), _initTxsUsdc[1], '');
    _mockAndExpect(address(factory), _initTxsUsdc[2], '');

    // Execute the initialization transactions
    factory.forTest_executeInitTxs(address(factory), _usdcInitializeData, _l2Adapter, _initTxsUsdc);
  }

  /**
   * @notice Check it properly reverts if the initialization transactions fail
   */
  function test_revertIfInitTxsOnArrayFail(address _l2Adapter) public {
    _mockExecuteTxsCalls();

    bytes[] memory _badInitTxs = _initTxsUsdc;
    for (uint256 _i; _i < _badInitTxs.length; _i++) {
      // Mock the calls
      vm.mockCall(address(factory), _badInitTxs[0], abi.encode(true));
      vm.mockCall(address(factory), _badInitTxs[1], abi.encode(false));
      vm.mockCall(address(factory), _badInitTxs[2], abi.encode(1));

      // Mock a revert only on the call corresponding to the for loop index
      vm.mockCallRevert(address(factory), _badInitTxs[_i], '');

      // Expect it to revert with the right index as argument
      vm.expectRevert(abi.encodeWithSelector(IL2OpUSDCDeploy.IL2OpUSDCDeploy_InitializationFailed.selector, _i + 1));
      // Execute
      factory.forTest_executeInitTxs(address(factory), _usdcInitializeData, _l2Adapter, _badInitTxs);
    }
  }

  function _mockExecuteTxsCalls() internal {
    // Mock call over `initialize()` function
    vm.mockCall(address(factory), abi.encodeWithSelector(IUSDC.initialize.selector), '');

    // Mock the call over `configureMinter()` function
    vm.mockCall(address(factory), abi.encodeWithSelector(IUSDC.configureMinter.selector), abi.encode(true));

    // Mock the call over `updateMasterMinter()` function
    vm.mockCall(address(factory), abi.encodeWithSelector(IUSDC.updateMasterMinter.selector), '');

    // Mock the call over `transferOwnership()` function
    vm.mockCall(address(factory), abi.encodeWithSelector(IUSDC.transferOwnership.selector), '');
  }
}

contract L2OpUSDCDeploy_Unit_DeployCreate is Base {
  /**
   * @notice Deploy the factory to test the internal function
   */
  function setUp() public override {
    super.setUp();

    vm.prank(_create2Deployer);
    new L2OpUSDCDeployForTest(_l1Adapter, _l2AdapterOwner, _usdcImplInitCode, _usdcInitializeData, _emptyInitTxs);
  }

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
    (address _newContract) = factory.forTest_deployCreate(_initCode);

    // Assert the deployed was deployed at the correct address and contract has code
    assertEq(_newContract, _expectedAddress);
    assertGt(_newContract.code.length, 0);
  }

  /**
   * @notice Check it reverts if the deployment fails
   */
  function test_revertIfDeploymentFailed() public {
    // Create a bad format for the init code to make the deployment revert
    bytes memory _badInitCode = '0x0000405060';

    // Expect the tx to revert
    vm.expectRevert(IL2OpUSDCDeploy.IL2OpUSDCDeploy_DeploymentFailed.selector);

    // Execute
    factory.forTest_deployCreate(_badInitCode);
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

  function returnOne() public pure returns (uint256) {
    return 1;
  }
}
