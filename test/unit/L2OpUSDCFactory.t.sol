// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {L2OpUSDCBridgeAdapter} from 'contracts/L2OpUSDCBridgeAdapter.sol';
import {L2OpUSDCFactory} from 'contracts/L2OpUSDCFactory.sol';
import {BytecodeDeployer} from 'contracts/utils/BytecodeDeployer.sol';
import {USDC_PROXY_CREATION_CODE} from 'contracts/utils/USDCProxyCreationCode.sol';
import {Test} from 'forge-std/Test.sol';
import {IL1OpUSDCFactory} from 'interfaces/IL1OpUSDCFactory.sol';
import {IL2OpUSDCFactory} from 'interfaces/IL2OpUSDCFactory.sol';
import {ICrossDomainMessenger} from 'interfaces/external/ICrossDomainMessenger.sol';
import {IUSDC} from 'interfaces/external/IUSDC.sol';
import {Helpers} from 'test/utils/Helpers.sol';

import 'forge-std/Test.sol';

contract L2OpUSDCFactoryTest is L2OpUSDCFactory {
  constructor(address _l1Factory, bytes32 _salt) L2OpUSDCFactory(_l1Factory, _salt) {}

  function forTest_deployCreate(bytes memory _initCode) public returns (address _newContract, bool _success) {
    (_newContract, _success) = _deployCreate(_initCode);
  }

  function forTest_deployCreate2(
    bytes32 _salt,
    bytes memory _initCode
  ) public returns (address _newContract, bool _success) {
    (_newContract, _success) = _deployCreate2(_salt, _initCode);
  }

  function forTest_executeInitTxs(address _target, bytes[] memory _initTxs, uint256 _length) public {
    _executeInitTxs(_target, _initTxs, _length);
  }

  function forTest_getSalt() public view returns (bytes32 _salt) {
    _salt = _SALT;
  }
}

contract Base is Test, Helpers {
  L2OpUSDCFactoryTest public factory;

  address internal _l2Messenger = 0x4200000000000000000000000000000000000007;
  bytes32 internal _salt = bytes32('32');
  address internal _l1Factory = makeAddr('l1Factory');
  address internal _usdc = makeAddr('opUSDC');

  address internal _messenger = makeAddr('messenger');
  address internal _create2Deployer = makeAddr('create2Deployer');
  address internal _l1Adapter = makeAddr('_l1Adapter');
  address internal _l2Adapter;

  address internal _dummyContract;
  address internal _dummyContractTwo;
  bytes internal _usdcImplBytecode;

  bytes[] internal _emptyInitTxs;
  bytes[] internal _initTxsUsdc;
  bytes[] internal _badInitTxs;

  function setUp() public virtual {
    // Deploy the l2 factory
    vm.prank(_create2Deployer);
    factory = new L2OpUSDCFactoryTest(_l1Factory, _salt);

    // Set the implementations bytecode and init code
    _dummyContract = address(new ForTestDummyContract());
    _usdcImplBytecode = _dummyContract.code;

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
    assertEq(factory.forTest_getSalt(), _salt);
  }
}

contract L2OpUSDCFactory_Unit_Deploy is Base {
  event USDCImplementationDeployed(address _l2UsdcImplementation);
  event USDCProxyDeployed(address _l2UsdcProxy);
  event L2AdapterDeployed(address _l2Adapter);

  /**
   * @notice Check it reverts if the sender is not the L2 messenger
   */
  function test_revertIfSenderNotMessenger(address _sender) public {
    vm.assume(_sender != factory.L2_MESSENGER());
    vm.expectRevert(IL2OpUSDCFactory.IL2OpUSDCFactory_InvalidSender.selector);
    // Execute
    vm.prank(_sender);
    factory.deploy(_l1Adapter, _usdcImplBytecode, _initTxsUsdc);
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
    factory.deploy(_l1Adapter, _usdcImplBytecode, _initTxsUsdc);
  }

  /**
   * @notice Check the deployment of the USDC implementation and proxy is properly done by checking the emitted event
   * and the 'upgradeTo' call to the proxy
   */
  function test_deployUsdcImplementation() public {
    // Get the usdc implementation address
    bytes memory _usdcImplInitCode = bytes.concat(type(BytecodeDeployer).creationCode, abi.encode(_usdcImplBytecode));
    address _usdcImplementation = _precalculateCreate2Address(_salt, keccak256(_usdcImplInitCode), address(factory));

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
    factory.deploy(_l1Adapter, _usdcImplBytecode, _emptyInitTxs);

    // Assert the USDC implementation was deployed
    assertGt(_usdcImplementation.code.length, 0, 'USDC implementation was not deployed');
  }

  /**
   * @notice Check the deployment of the L2 adapter implementation and proxy is properly done by checking the emitted
   * event and the 'upgradeToAndCall' call to the proxy
   */
  function test_deployUsdcProxy() public {
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
    factory.deploy(_l1Adapter, _usdcImplBytecode, _emptyInitTxs);

    // Assert the USDC proxy was deployed
    assertGt(_usdcProxy.code.length, 0, 'USDC proxy was not deployed');
  }

  function test_deployAdapter() public {
    // Calculate the usdc proxy address
    uint256 _usdcProxyDeploymentNonce = vm.getNonce(address(factory)) + 1;
    address _usdcProxy = _precalculateCreateAddress(address(factory), _usdcProxyDeploymentNonce);

    // Get the adapter address
    bytes memory _l2AdapterCArgs = abi.encode(_usdcProxy, _l2Messenger, _l1Adapter);
    bytes memory _l2AdapterInitCode = bytes.concat(type(L2OpUSDCBridgeAdapter).creationCode, _l2AdapterCArgs);
    _l2Adapter = _precalculateCreate2Address(_salt, keccak256(_l2AdapterInitCode), address(factory));

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
    factory.deploy(_l1Adapter, _usdcImplBytecode, _emptyInitTxs);

    // Assert the adapter was deployed
    assertGt(_l2Adapter.code.length, 0, 'Adapter was not deployed');
  }

  function test_revertOnFailedUsdcImplementationDeployment() public {
    // Deploy the USDC implementation to the same address as the factory to make it fail
    bytes memory _usdcImplInitCode = bytes.concat(type(BytecodeDeployer).creationCode, abi.encode(_usdcImplBytecode));
    address _usdcImplementation = _precalculateCreate2Address(_salt, keccak256(_usdcImplInitCode), address(factory));

    // Set bytecode to the address where the USDC implementation will be deployed to make it fail
    vm.etch(_usdcImplementation, _usdcImplBytecode);

    // Mock the call over `xDomainMessageSender` to return the L1 factory address
    vm.mockCall(
      factory.L2_MESSENGER(),
      abi.encodeWithSelector(ICrossDomainMessenger.xDomainMessageSender.selector),
      abi.encode(factory.L1_FACTORY())
    );

    // Expect the tx to revert
    vm.expectRevert(IL2OpUSDCFactory.IL2OpUSDCFactory_DeploymentsFailed.selector);

    // Execute
    vm.prank(_l2Messenger);
    factory.deploy(_l1Adapter, _usdcImplBytecode, _emptyInitTxs);
  }

  function test_revertOnFailedUsdcProxyDeployment() public {
    // Calculate the usdc proxy address
    uint256 _usdcProxyDeploymentNonce = vm.getNonce(address(factory)) + 1;
    address _usdcProxy = _precalculateCreateAddress(address(factory), _usdcProxyDeploymentNonce);

    // Set bytecode to the address where the USDC will be deployed to make it fail
    vm.etch(_usdcProxy, _usdcImplBytecode);

    // Mock the call over `xDomainMessageSender` to return the L1 factory address
    vm.mockCall(
      factory.L2_MESSENGER(),
      abi.encodeWithSelector(ICrossDomainMessenger.xDomainMessageSender.selector),
      abi.encode(factory.L1_FACTORY())
    );

    // Expect the tx to revert
    vm.expectRevert(IL2OpUSDCFactory.IL2OpUSDCFactory_DeploymentsFailed.selector);

    // Execute
    vm.prank(_l2Messenger);
    factory.deploy(_l1Adapter, _usdcImplBytecode, _emptyInitTxs);
  }

  function test_revertOnFailedAdapterDeployment() public {
    // Calculate the usdc proxy address
    uint256 _usdcProxyDeploymentNonce = vm.getNonce(address(factory)) + 1;
    address _usdcProxy = _precalculateCreateAddress(address(factory), _usdcProxyDeploymentNonce);

    // Deploy the L2 adapter to the same address as the factory to make it fail
    bytes memory _l2AdapterCArgs = abi.encode(_usdcProxy, _l2Messenger, _l1Adapter);
    bytes memory _l2AdapterInitCode = bytes.concat(type(L2OpUSDCBridgeAdapter).creationCode, _l2AdapterCArgs);
    address _l2Adapter = _precalculateCreate2Address(_salt, keccak256(_l2AdapterInitCode), address(factory));

    // Set bytecode to the address where the L2 Adapter will be deployed
    vm.etch(_l2Adapter, _usdcImplBytecode);

    // Mock the call over `xDomainMessageSender` to return the L1 factory address
    vm.mockCall(
      factory.L2_MESSENGER(),
      abi.encodeWithSelector(ICrossDomainMessenger.xDomainMessageSender.selector),
      abi.encode(factory.L1_FACTORY())
    );

    // Expect the tx to revert
    vm.expectRevert(IL2OpUSDCFactory.IL2OpUSDCFactory_DeploymentsFailed.selector);

    // Execute
    vm.prank(_l2Messenger);
    factory.deploy(_l1Adapter, _usdcImplBytecode, _emptyInitTxs);
  }

  /**
   * @notice Check the `changeAdmin` function is called on the USDC proxy
   */
  function test_callChangeAdmin() public {
    // Get the usdc proxy address
    uint256 _usdcProxyDeploymentNonce = vm.getNonce(address(factory)) + 1;
    address _usdcProxy = _precalculateCreateAddress(address(factory), _usdcProxyDeploymentNonce);

    // Get the adapter address
    bytes memory _l2AdapterCArgs = abi.encode(_usdcProxy, _l2Messenger, _l1Adapter);
    bytes memory _l2AdapterInitCode = bytes.concat(type(L2OpUSDCBridgeAdapter).creationCode, _l2AdapterCArgs);
    _l2Adapter = _precalculateCreate2Address(_salt, keccak256(_l2AdapterInitCode), address(factory));

    // Mock the call over `xDomainMessageSender` to return the L1 factory address
    vm.mockCall(
      _l2Messenger, abi.encodeWithSelector(ICrossDomainMessenger.xDomainMessageSender.selector), abi.encode(_l1Factory)
    );

    // Expect the call over 'changeAdmin' function
    vm.expectCall(_usdcProxy, abi.encodeWithSelector(IUSDC.changeAdmin.selector, address(_l2Adapter)));

    // Execute
    vm.prank(_l2Messenger);
    factory.deploy(_l1Adapter, _usdcImplBytecode, _emptyInitTxs);
  }

  /**
   * @notice Check init txs are properly executed over the USDC implementation and proxy
   */
  function test_executeUsdcImplInitTxs() public {
    // Get the usdc implementation address
    bytes memory _usdcImplInitCode = bytes.concat(type(BytecodeDeployer).creationCode, abi.encode(_usdcImplBytecode));
    address _usdcImplementation = _precalculateCreate2Address(_salt, keccak256(_usdcImplInitCode), address(factory));
    vm.mockCall(
      _l2Messenger, abi.encodeWithSelector(ICrossDomainMessenger.xDomainMessageSender.selector), abi.encode(_l1Factory)
    );

    // Expect the init txs to be called
    vm.expectCall(_usdcImplementation, _initTxsUsdc[0]);
    vm.expectCall(_usdcImplementation, _initTxsUsdc[1]);

    // Execute
    vm.prank(_l2Messenger);
    factory.deploy(_l1Adapter, _usdcImplBytecode, _initTxsUsdc);
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
    factory.deploy(_l1Adapter, _usdcImplBytecode, _initTxsUsdc);
  }
}

contract L2OpUSDCFactory_Unit_ExecuteInitTxs is Base {
  /**
   * @notice Check the execution of the initialization transactions over a target contract
   */
  function test_executeInitTxs() public {
    // Mock the call to the target contract
    _mockAndExpect(_dummyContract, _initTxsUsdc[0], '');
    _mockAndExpect(_dummyContract, _initTxsUsdc[1], '');

    // Execute the initialization transactions
    factory.forTest_executeInitTxs(_dummyContract, _initTxsUsdc, _initTxsUsdc.length);
  }

  /**
   * @notice Check it reverts if the initialization transactions fail
   */
  function test_revertIfInitTxsFail() public {
    vm.mockCallRevert(_dummyContract, _badInitTxs[0], '');
    vm.mockCallRevert(_dummyContract, _badInitTxs[1], '');
    vm.expectRevert(IL2OpUSDCFactory.IL2OpUSDCFactory_InitializationFailed.selector);
    // Execute
    factory.forTest_executeInitTxs(_dummyContract, _badInitTxs, _badInitTxs.length);
  }
}

contract L2OpUSDCFactory_Unit_DeployCreate2 is Base {
  /**
   * @notice Check the deployment of a contract using the `CREATE2` opcode is properly done to the expected addrtess
   */
  function test_deployCreate2() public {
    // Get the init code with the USDC proxy creation code plus the USDC implementation address
    bytes memory _initCode = bytes.concat(USDC_PROXY_CREATION_CODE, abi.encode(address(factory)));

    // Precalculate the address of the contract that will be deployed with the current factory's nonce
    address _expectedAddress = _precalculateCreate2Address(_salt, keccak256(_initCode), address(factory));

    // Execute
    (address _newContract, bool _success) = factory.forTest_deployCreate2(_salt, _initCode);

    // Assert the deployed was deployed at the correct address and contract has code
    assertEq(_newContract, _expectedAddress);
    assertGt(_newContract.code.length, 0);
    assertTrue(_success);
  }

  /**
   * @notice Check correctly deploys when also using the BytecodeDeployer contract as the creation code and the another
   * contract's bytecode as the constructor argument
   */
  function test_create2BytecodeDeployer() public {
    // Get the creation code of the bytecode deployer with the dummy contract code as constructor argument
    bytes memory _initCode = bytes.concat(type(BytecodeDeployer).creationCode, abi.encode(_dummyContract.code));
    address _expectedAddress = _precalculateCreate2Address(_salt, keccak256(_initCode), address(factory));

    // Execute
    (address _newContract, bool _success) = factory.forTest_deployCreate2(_salt, _initCode);

    // Assert the deployed was deployed at the correct address and contract has code
    assertEq(_newContract, _expectedAddress);
    assertGt(_expectedAddress.code.length, 0);
    assertTrue(_success);
  }

  /**
   * @notice Check it reverts if the deployment fails
   */
  function test_revertIfDeploymentFailed() public {
    // Create a bad format for the init code to make the deployment revert
    bytes memory _badInitCode = '0x0000405060';

    // Expect the `Create2DeploymentFailed` event to be emitted
    vm.expectEmit(true, true, true, true);
    emit IL2OpUSDCFactory.Create2DeploymentFailed();

    // Execute
    (, bool _success) = factory.forTest_deployCreate2(_salt, _badInitCode);

    // Assert the deployment failed
    assertFalse(_success);
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

  function returnTrue() public pure returns (bool) {
    return true;
  }

  function returnFalse() public pure returns (bool) {
    return true;
  }
}
