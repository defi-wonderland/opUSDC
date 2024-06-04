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

  function forTest_deployCreate2(bytes32 _salt, bytes memory _initCode) public returns (address _newContract) {
    _newContract = _deployCreate2(_salt, _initCode);
  }

  function forTest_executeInitTxs(address _target, bytes[] memory _initTxs, uint256 _length) public {
    _executeInitTxs(_target, _initTxs, _length);
  }

  function forTest_getImplementation() public view returns (address __implementation) {
    __implementation = ERC1967Utils.getImplementation();
  }

  function forTest_getSalt() public view returns (bytes32 _salt) {
    _salt = _SALT;
  }
}

contract Base is Test, Helpers {
  L2OpUSDCFactoryTest public factory;

  address internal _weth = 0x4200000000000000000000000000000000000006;
  address internal _l2Messenger = 0x4200000000000000000000000000000000000007;
  bytes32 internal _salt = bytes32('1');
  address internal _l1Factory = makeAddr('l1Factory');
  address internal _deployer = makeAddr('deployer');
  address internal _owner = makeAddr('owner');
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

  address internal _dummyContract;
  address internal _dummyContractTwo;

  bytes[] internal _emptyInitTxs;
  bytes[] internal _initTxsUsdc;
  bytes[] internal _initTxsAdapter;
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
    _dummyContract = address(new ForTestDummyContract());
    _usdcProxyInitCode = type(ForTestDummyContract).creationCode;
    _usdcImplBytecode = _dummyContract.code;

    _dummyContractTwo = address(new ForTestDummyContractTwo());
    _l2AdapterBytecode = type(ForTestDummyContractTwo).creationCode;
    _l2AdapterBytecode = _dummyContractTwo.code;

    _initTxOne = abi.encodeWithSignature('dummyFunction()');
    _initTxTwo = abi.encodeWithSignature('dummyFunctionFalse()');
    _initTxsUsdc = new bytes[](2);
    _initTxsUsdc[0] = _initTxOne;
    _initTxsUsdc[1] = _initTxTwo;

    _initTxOne = abi.encodeWithSignature('dummyFunctionTwo()');
    _initTxTwo = abi.encodeWithSignature('dummyFunctionTwoFalse()');
    _initTxsAdapter = new bytes[](2);
    _initTxsAdapter[0] = _initTxOne;
    _initTxsAdapter[1] = _initTxTwo;

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
  ) internal pure returns (address computedAddress) {
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
    factory.deploy(_usdcImplBytecode, _initTxsUsdc, _owner, _l2AdapterBytecode, _initTxsAdapter);
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
    factory.deploy(_usdcImplBytecode, _initTxsUsdc, _owner, _l2AdapterBytecode, _initTxsAdapter);
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
    factory.deploy(_usdcImplBytecode, _emptyInitTxs, _owner, _l2AdapterBytecode, _emptyInitTxs);
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

    bytes memory _adapterInitTx = abi.encodeWithSignature('setProxyExecutedInitTxs(uint256)', _emptyInitTxs.length);
    vm.expectCall(
      _l2AdapterProxy,
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, _l2AdapterImplementation, _adapterInitTx)
    );

    // Expect the adapter deployment event to be properly emitted
    vm.expectEmit(true, true, true, true);
    emit AdapterDeployed(_l2AdapterProxy, _l2AdapterImplementation);

    // Deploy the L2 adapter implementation and proxy
    vm.prank(_l2Messenger);
    factory.deploy(_usdcImplBytecode, _emptyInitTxs, _owner, _l2AdapterBytecode, _emptyInitTxs);
  }

  function test_executeUsdcImplInitTxs() public {
    bytes memory _usdcImplInitCode = bytes.concat(type(BytecodeDeployer).creationCode, abi.encode(_usdcImplBytecode));
    address _usdcImplementation = _precalculateCreate2Address(_salt, keccak256(_usdcImplInitCode), address(factory));
    vm.mockCall(
      _l2Messenger, abi.encodeWithSelector(ICrossDomainMessenger.xDomainMessageSender.selector), abi.encode(_l1Factory)
    );

    vm.expectCall(_usdcImplementation, _initTxsUsdc[0]);
    vm.expectCall(_usdcImplementation, _initTxsUsdc[1]);

    vm.prank(_l2Messenger);
    factory.deploy(_usdcImplBytecode, _initTxsUsdc, _owner, _l2AdapterBytecode, _emptyInitTxs);
  }

  function test_executeUsdcProxyInitTxs() public {
    bytes memory _usdcProxyInitCode = bytes.concat(USDC_PROXY_CREATION_CODE, abi.encode(_weth));
    address _usdcProxy = _precalculateCreate2Address(_salt, keccak256(_usdcProxyInitCode), address(factory));

    vm.mockCall(
      _l2Messenger, abi.encodeWithSelector(ICrossDomainMessenger.xDomainMessageSender.selector), abi.encode(_l1Factory)
    );

    vm.expectCall(_usdcProxy, abi.encodeWithSelector(IUSDC.changeAdmin.selector, _owner));

    vm.expectCall(_usdcProxy, _initTxsUsdc[0]);
    vm.expectCall(_usdcProxy, _initTxsUsdc[1]);

    vm.prank(_l2Messenger);
    factory.deploy(_usdcImplBytecode, _initTxsUsdc, _owner, _l2AdapterBytecode, _emptyInitTxs);
  }

  function test_executeAdapterInitTxs() public {
    bytes memory _l2AdapterProxyInitCode = bytes.concat(type(ERC1967Proxy).creationCode, abi.encode(_weth, ''));

    address _l2AdapterProxy = _precalculateCreate2Address(_salt, keccak256(_l2AdapterProxyInitCode), address(factory));

    vm.mockCall(
      _l2Messenger, abi.encodeWithSelector(ICrossDomainMessenger.xDomainMessageSender.selector), abi.encode(_l1Factory)
    );

    vm.expectCall(_l2AdapterProxy, _initTxOne);
    vm.expectCall(_l2AdapterProxy, _initTxTwo);

    vm.prank(_l2Messenger);
    factory.deploy(_usdcImplBytecode, _emptyInitTxs, _owner, _l2AdapterBytecode, _initTxsAdapter);
  }
}

contract L2OpUSDCFactory_Unit_ExecuteInitTxs is Base {
  function test_executeInitTxs() public {
    // Mock the call to the target contract
    _mockAndExpect(_dummyContract, _initTxsUsdc[0], '');
    _mockAndExpect(_dummyContract, _initTxsUsdc[1], '');

    // Execute the initialization transactions
    factory.forTest_executeInitTxs(_dummyContract, _initTxsUsdc, _initTxsUsdc.length);
  }

  function test_revertIfInitTxsFail() public {
    vm.mockCallRevert(_dummyContract, _badInitTxs[0], '');
    vm.mockCallRevert(_dummyContract, _badInitTxs[1], '');

    vm.expectRevert(IL2OpUSDCFactory.IL2OpUSDCFactory_InitializationFailed.selector);
    factory.forTest_executeInitTxs(_dummyContract, _badInitTxs, _badInitTxs.length);
  }
}

contract L2OpUSDCFactory_Unit_DeployCreate2 is Base {
  function test_deployCreate2() public {
    // Get the init code with the USDC proxy creation code plus the USDC implementation address
    bytes memory _initCode = bytes.concat(_usdcProxyInitCode, abi.encode(_usdcImplementation));
    // Precalculate the address of the contract that will be deployed with the current factory's nonce
    address _expectedAddress = _precalculateCreate2Address(_salt, keccak256(_initCode), address(factory));

    // Execute
    address _newContract = factory.forTest_deployCreate2(_salt, _initCode);

    // Assert the deployed was deployed at the correct address and contract has code
    assertEq(_newContract, _expectedAddress);
    assertGt(_newContract.code.length, 0);
  }

  function test_create2BytecodeDeployer() public {
    // Get the creation code of the bytecode deployer with the dummy contract code as constructor argument
    bytes memory _initCode = bytes.concat(type(BytecodeDeployer).creationCode, abi.encode(_dummyContract.code));
    address _expectedAddress = _precalculateCreate2Address(_salt, keccak256(_initCode), address(factory));

    // Execute
    address _newContract = factory.forTest_deployCreate2(_salt, _initCode);

    // Assert the deployed was deployed at the correct address and contract has code
    assertEq(_newContract, _expectedAddress);
    assertGt(_expectedAddress.code.length, 0);
  }

  function test_revertIfDeploymentFailed() public {
    // Create a bad format for the init code to test the deployment revert
    bytes memory _badInitCode = '0x0000405060';
    vm.expectRevert(IL2OpUSDCFactory.IL2OpUSDCFactory_Create2DeploymentFailed.selector);
    factory.forTest_deployCreate2(_salt, _badInitCode);
  }
}

/**
 * @notice Dummy contract used only for testing purposes
 */
contract ForTestDummyContract {
  function dummyFunction() public pure returns (bool) {
    return true;
  }

  function dummyFunctionFalse() public pure returns (bool) {
    return true;
  }
}

/**
 * @notice Dummy contract used only for testing purposes
 */
contract ForTestDummyContractTwo {
  function dummyFunctionTwo() public pure returns (bool) {
    return true;
  }

  function dummyFunctionTwoFalse() public pure returns (bool) {
    return false;
  }
}
