// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import {ERC1967Proxy} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import {ERC1967Utils} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol';
import {L2OpUSDCFactory} from 'contracts/L2OpUSDCFactory.sol';
import {BytecodeDeployer} from 'contracts/utils/BytecodeDeployer.sol';
import {USDC_PROXY_CREATION_CODE} from 'contracts/utils/USDCProxyCreationCode.sol';
import {Test} from 'forge-std/Test.sol';
import {IL2OpUSDCFactory} from 'interfaces/IL2OpUSDCFactory.sol';
import {ICrossDomainMessenger} from 'interfaces/external/ICrossDomainMessenger.sol';
import {IUSDC} from 'interfaces/external/IUSDC.sol';
import {Helpers} from 'test/utils/Helpers.sol';

contract L2OpUSDCFactoryTest is L2OpUSDCFactory {
  constructor(bytes32 _salt, address _l1Factory) L2OpUSDCFactory(_salt, _l1Factory) {}

  function forTest_getImplementation() public view returns (address __implementation) {
    __implementation = ERC1967Utils.getImplementation();
  }

  function forTest_deployCreate2(bytes32 _salt, bytes memory _initCode) public returns (address _newContract) {
    _newContract = _deployCreate2(_salt, _initCode);
  }

  function forTest_getSalt() public view returns (bytes32 _salt) {
    _salt = _SALT;
  }
}

contract Base is Test, Helpers {
  error Create2DeploymentFailed();

  L2OpUSDCFactoryTest public factory;

  address internal _weth = 0x4200000000000000000000000000000000000006;
  address internal _l2Messenger = 0x4200000000000000000000000000000000000007;
  bytes32 internal _salt = bytes32('1');
  address internal _l1Factory = makeAddr('l1Factory');
  address internal _deployer = makeAddr('deployer');
  address internal _create2Deployer = makeAddr('create2Deployer');
  bytes internal _wethBytecode = '0x60809020';
  bytes internal _usdcProxyInitCode;
  bytes internal _usdcImplBytecode;
  bytes internal _l2AdapterBytecode;
  address internal _usdcImplementation;
  address internal _usdcProxy;
  address internal _l2AdapterImplementation;

  address internal _usdc = makeAddr('opUSDC');
  address internal _messenger = makeAddr('messenger');
  address internal _linkedAdapter = makeAddr('linkedAdapter');

  bytes[] internal _emptyInitTxs;
  bytes[] internal _initTxs;
  bytes[] internal _badInitTxs;

  bytes internal _initTxOne;
  bytes internal _initTxTwo;

  function setUp() public virtual {
    // Deploy the l2 factory
    bytes memory _initCode = bytes.concat(type(L2OpUSDCFactoryTest).creationCode, abi.encode(_salt, _l1Factory));
    vm.prank(_create2Deployer);
    bytes32 _deploymentSalt = _salt;
    address _factoryAddress;
    assembly ("memory-safe") {
      _factoryAddress := create2(callvalue(), add(_initCode, 0x20), mload(_initCode), _deploymentSalt)
    }
    if (_factoryAddress == address(0) || _factoryAddress.code.length == 0) {
      revert Create2DeploymentFailed();
    }
    factory = L2OpUSDCFactoryTest(_factoryAddress);

    // Set the weth bytecode
    vm.etch(_weth, _wethBytecode);

    // Set the implementations bytecode and init code
    address _dummyContract = address(new ForTestDummyContract());
    _usdcProxyInitCode = type(ForTestDummyContract).creationCode;
    _usdcImplBytecode = _dummyContract.code;

    address _dummyContractTwo = address(new ForTestDummyContractTwo());
    _l2AdapterBytecode = type(ForTestDummyContractTwo).creationCode;
    _l2AdapterBytecode = _dummyContractTwo.code;

    _initTxOne = abi.encodeWithSignature('dummyFunction()');
    _initTxTwo = abi.encodeWithSignature('dummyFunctionTwo()');
    _initTxs = new bytes[](2);
    _initTxs[0] = _initTxOne;
    _initTxs[1] = _initTxTwo;

    // Set the bad init transaction to test when the initialization fails
    bytes memory _badInitTx = abi.encodeWithSignature('nonExistentFunction()');
    _badInitTxs = new bytes[](2);
    _badInitTxs[0] = '';
    _badInitTxs[1] = _badInitTx;

    // _usdcImplementation = _precalculateCreate2Address(_salt, address(factory));
    // _usdcProxy = _precalculateCreate2Address(_salt, address(factory));
    // _l2AdapterImplementation = _precalculateCreate2Address(_salt, address(factory));
    // _l2AdapterProxy = _precalculateCreate2Address(_salt, address(factory));
  }

  /**
   * @notice Precalculate and address to be deployed using the `CREATE2` opcode
   * @param salt The 32-byte random value used to create the contract address.
   * @param initCodeHash The 32-byte bytecode digest of the contract creation bytecode.
   * @param deployer The 20-byte deployer address.
   * @return computedAddress The 20-byte address where a contract will be stored.
   */
  function _precalculateCreate2Address(
    bytes32 salt,
    bytes32 initCodeHash,
    address deployer
  ) public pure returns (address computedAddress) {
    assembly ("memory-safe") {
      let ptr := mload(0x40)
      mstore(add(ptr, 0x40), initCodeHash)
      mstore(add(ptr, 0x20), salt)
      mstore(ptr, deployer)
      let start := add(ptr, 0x0b)
      mstore8(start, 0xff)
      computedAddress := keccak256(start, 85)
    }
  }
}

contract L2OpUSDCFactory_Unit_Constructor is Base {
  function test_setImmutables() public {
    assertEq(factory.forTest_getSalt(), _salt);
    assertEq(factory.L1_FACTORY(), _l1Factory);
  }
}

contract L2OpUSDCFactory_Unit_Deploy is Base {
  event USDCDeployed(address _usdcProxy, address _usdcImplementation);
  event AdapterDeployed(address _adapterProxy, address _adapterImplementation);

  function test_revertIfSenderNotMessenger(address _sender) public {
    vm.assume(_sender != factory.L2_MESSENGER());
    vm.expectRevert(IL2OpUSDCFactory.IL2OpUSDCFactory_InvalidSender.selector);
    vm.prank(_sender);
    factory.deploy(_usdcImplBytecode, _initTxs, _l2AdapterBytecode, _initTxs);
  }

  function test_revertIfL1FactoryNotXDomainSender(address _xDomainSender) public {
    vm.assume(_xDomainSender != factory.L1_FACTORY());

    vm.mockCall(
      factory.L2_MESSENGER(),
      abi.encodeWithSelector(ICrossDomainMessenger.xDomainMessageSender.selector),
      abi.encode(_xDomainSender)
    );

    vm.prank(factory.L2_MESSENGER());
    vm.expectRevert(IL2OpUSDCFactory.IL2OpUSDCFactory_InvalidSender.selector);
    factory.deploy(_usdcImplBytecode, _initTxs, _l2AdapterBytecode, _initTxs);
  }

  function test_deployUsdc() public {
    bytes memory _usdcImplInitCode = bytes.concat(type(BytecodeDeployer).creationCode, abi.encode(_usdcImplBytecode));
    bytes memory _usdcProxyInitCode = bytes.concat(USDC_PROXY_CREATION_CODE, abi.encode(_weth));

    address _usdcImplementation = _precalculateCreate2Address(_salt, keccak256(_usdcImplInitCode), address(factory));
    address _usdcProxy = _precalculateCreate2Address(_salt, keccak256(_usdcProxyInitCode), address(factory));

    vm.mockCall(
      factory.L2_MESSENGER(),
      abi.encodeWithSelector(ICrossDomainMessenger.xDomainMessageSender.selector),
      abi.encode(factory.L1_FACTORY())
    );

    // Mock and expect call over 'upgradeTo' function
    vm.expectCall(_usdcProxy, abi.encodeWithSelector(IUSDC.upgradeTo.selector, _usdcImplementation));

    // Expect the USDC deployment event to be properly emitted
    vm.expectEmit(true, true, true, true);
    emit USDCDeployed(_usdcProxy, _usdcImplementation);

    // Deploy the USDC implementation and proxy
    vm.prank(_l2Messenger);
    factory.deploy(_usdcImplBytecode, _emptyInitTxs, _l2AdapterBytecode, _emptyInitTxs);
  }

  function test_deployAdapter() public {
    bytes memory _l2AdapterImplInitCode =
      bytes.concat(type(BytecodeDeployer).creationCode, abi.encode(_l2AdapterBytecode));
    bytes memory _l2AdapterProxyInitCode = bytes.concat(type(ERC1967Proxy).creationCode, abi.encode(_weth, ''));

    address _l2AdapterImplementation =
      _precalculateCreate2Address(_salt, keccak256(_l2AdapterImplInitCode), address(factory));
    address _l2AdapterProxy = _precalculateCreate2Address(_salt, keccak256(_l2AdapterProxyInitCode), address(factory));

    vm.mockCall(
      factory.L2_MESSENGER(),
      abi.encodeWithSelector(ICrossDomainMessenger.xDomainMessageSender.selector),
      abi.encode(factory.L1_FACTORY())
    );

    vm.expectCall(
      _l2AdapterProxy, abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, _l2AdapterImplementation, '')
    );

    // Expect the adapter deployment event to be properly emitted
    vm.expectEmit(true, true, true, true);
    emit AdapterDeployed(_l2AdapterProxy, _l2AdapterImplementation);

    // Deploy the L2 adapter implementation and proxy
    vm.prank(_l2Messenger);
    factory.deploy(_usdcImplBytecode, _emptyInitTxs, _l2AdapterBytecode, _emptyInitTxs);
  }
}

// contract L2OpUSDCFactory_Unit_Constructor is Base {
//   event DeployedUSDCImpl(address _usdcImplementation);
//   event DeployedUSDCProxy(address _usdcProxy);
//   event DeployedL2AdapterImplementation(address _l2AdapterImplementation);
//   event DeployedL2AdapterProxy(address _l2AdapterProxy);

//   /**
//    * @notice Check the USDC implementation contract was correctly deployed and the event was emitted
//    */
//   function test_deployUsdcImplementationAndEmit() public {
//     vm.expectEmit(true, true, true, true);
//     emit DeployedUSDCImpl(_usdcImplementation);

//     bytes memory _l2UsdcProxyInitCodeHash = bytes.concat(USDC_PROXY_CREATION_CODE, abi.encode(address(0)));
//     // Calculate the L2 adapter proxy address
//     bytes memory _l2AdapterProxyInitCodeHash = bytes.concat(type(ERC1967Proxy).creationCode, abi.encode(address(0), ''));

//     vm.prank(0x835aA28793d2135a4f6bc3e6b62Aa5aF9e6eAD20);
//     new L2OpUSDCFactoryTest(_salt, _l1Factory);

//     // Assert the deployed contract has code
//     assertGt(_usdcImplementation.code.length, 0);
//   }

//   /**
//    * @notice Check the USDC proxy contract was correctly deployed and the event was emitted
//    */
//   function test_deployUsdcProxyAndEmit() public {
//     vm.expectEmit(true, true, true, true);
//     emit DeployedUSDCProxy(_usdcProxy);

//     vm.prank(_deployer);
//     new L2OpUSDCFactoryTest(_salt, _l1Factory);

//     // Assert the deployed contract has code
//     assertGt(_usdcProxy.code.length, 0);
//   }

//   /**
//    * @notice Check the L2 adapter contract was correctly deployed and the event was emitted
//    */
//   function test_deployL2AdapterImplementationAndEmit() public {
//     vm.expectEmit(true, true, true, true);
//     emit DeployedL2AdapterImplementation(_l2AdapterImplementation);

//     vm.prank(_deployer);
//     new L2OpUSDCFactoryTest(_salt, _l1Factory);

//     // Assert the deployed contract has code
//     assertGt(_l2AdapterImplementation.code.length, 0);
//   }

//   function test_deployL2AdapterProxyAndEmit() public {
//     vm.expectEmit(true, true, true, true);
//     emit DeployedL2AdapterProxy(_l2AdapterProxy);

//     vm.prank(_deployer);
//     new L2OpUSDCFactoryTest(_salt, _l1Factory);

//     // Assert the deployed contract has code
//     assertGt(_l2AdapterProxy.code.length, 0);
//   }

//   /**
//    * @notice Check the USDC implementation calls revert on bad transactions
//    */
//   function test_revertOnUSDCImplementationBadTxs() public {
//     vm.expectRevert(IL2OpUSDCFactory.IL2OpUSDCFactory_InitializationFailed.selector);
//     new L2OpUSDCFactoryTest(_salt, _l1Factory);
//   }

//   /**
//    * @notice Check the USDC implementation initialization transactions were correctly executed
//    */
//   function test_callUsdcImplementationInitTxs() public {
//     vm.expectCall(_usdcImplementation, _initTxs[0]);
//     vm.expectCall(_usdcImplementation, _initTxs[1]);

//     vm.prank(_deployer);
//     new L2OpUSDCFactoryTest(_salt, _l1Factory);
//   }

//   /**
//    * @notice Check the L2 adapter calls revert on bad transactions
//    */
//   function test_revertOnL2AdapterBadTxs() public {
//     vm.expectRevert(IL2OpUSDCFactory.IL2OpUSDCFactory_InitializationFailed.selector);
//     new L2OpUSDCFactoryTest(_salt, _l1Factory);
//   }

//   /**
//    * @notice Check the L2 adapter initialization transactions were correctly executed
//    */
//   function test_callL2AdapterInitTxs() public {
//     vm.expectCall(_l2AdapterProxy, _initTxOne);
//     vm.expectCall(_l2AdapterProxy, _initTxTwo);

//     vm.prank(_deployer);
//     new L2OpUSDCFactoryTest(_salt, _l1Factory);
//   }
// }

// contract L2OpUSDCFactory_Unit_CreateDeploy is Base {
//   L2OpUSDCFactoryTest _factory;

//   function setUp() public override {
//     super.setUp();
//     // Deploy the factory for the next tests
//     _factory = new L2OpUSDCFactoryTest(_salt, _l1Factory);
//   }

//   /**
//    * @notice Check the factory correctly deploys a new contract through the `CREATE` opcode
//    */
//   function test_createDeploy() public {
//     // Get the init code with the USDC proxy creation code plus the USDC implementation address
//     bytes memory _initCode = bytes.concat(_usdcProxyInitCode, abi.encode(_usdcImplementation));
//     // Precalculate the address of the contract that will be deployed with the current factory's nonce
//     uint256 _nonce = vm.getNonce(address(_factory));
//     address _expectedAddress = _precalculateCreateAddress(address(_factory), _nonce);

//     // Execute
//     vm.prank(_deployer);
//     address _newContract = _factory.forTest_deployCreate2(_salt, _initCode);

//     // Assert the deployed contract has code
//     assertEq(_newContract, _expectedAddress);
//     assertGt(_newContract.code.length, 0);
//   }

//   /**
//    * @notice Check the factory reverts if the deployment failed
//    * @dev It only works with creation code, but not with bytecode so it should revert when using bytecode
//    */
//   function test_revertIfDeploymentFailed() public {
//     vm.expectRevert(IL2OpUSDCFactory.IL2OpUSDCFactory_Create2DeploymentFailed.selector);
//     _factory.forTest_deployCreate2(_salt, _usdcImplBytecode);
//   }
// }

/**
 * @notice Dummy contract used only for testing purposes
 */
contract ForTestDummyContract {
  function dummyFunction() public pure returns (bool) {
    return true;
  }

  function dummyFunctionTwo() public pure returns (bool) {
    return true;
  }
}

/**
 * @notice Dummy contract used only for testing purposes
 */
contract ForTestDummyContractTwo {
  function dummyFunction() public pure returns (bool) {
    return false;
  }

  function dummyFunctionTwo() public pure returns (bool) {
    return false;
  }
}
