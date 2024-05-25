// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {L2OpUSDCFactory} from 'contracts/L2OpUSDCFactory.sol';
import {Test} from 'forge-std/Test.sol';
import {IL2OpUSDCFactory} from 'interfaces/IL2OpUSDCFactory.sol';
import {Helpers} from 'test/utils/Helpers.sol';

contract L2OpUSDCFactoryTest is L2OpUSDCFactory {
  constructor(
    bytes memory _usdcProxyInitCode,
    bytes memory _usdcImplBytecode,
    bytes[] memory _usdcImplInitTxs,
    bytes memory _l2AdapterBytecode,
    bytes[] memory _l2AdapterInitTxs
  ) L2OpUSDCFactory(_usdcProxyInitCode, _usdcImplBytecode, _usdcImplInitTxs, _l2AdapterBytecode, _l2AdapterInitTxs) {}

  function forTest_createDeploy(bytes memory _initCode) public returns (address _newContract) {
    _newContract = _createDeploy(_initCode);
  }
}

contract Base is Test, Helpers {
  L2OpUSDCFactoryTest public factory;

  address internal _deployer = makeAddr('deployer');
  bytes internal _usdcProxyInitCode;
  bytes internal _usdcImplBytecode;
  bytes internal _l2AdapterBytecode;
  address internal _usdcImplementation;
  address internal _usdcProxy;
  address internal _l2Adapter;

  bytes[] internal _emptyInitTxs;
  bytes[] internal _initTxs;
  bytes[] internal _badInitTxs;

  bytes internal _initTxOne;
  bytes internal _initTxTwo;

  function setUp() public virtual {
    address _dummyContract = address(new ForTestDummyContract());
    _usdcProxyInitCode = type(ForTestDummyContract).creationCode;
    _usdcImplBytecode = _dummyContract.code;
    _l2AdapterBytecode = _dummyContract.code;

    _initTxOne = abi.encodeWithSignature('dummyFunction()');
    _initTxTwo = abi.encodeWithSignature('dummyFunctionTwo()');
    _initTxs = new bytes[](2);
    _initTxs[0] = _initTxOne;
    _initTxs[1] = _initTxTwo;

    bytes memory _badInitTx = abi.encodeWithSignature('nonExistentFunction()');
    _badInitTxs = new bytes[](1);
    _badInitTxs[0] = _badInitTx;

    factory = L2OpUSDCFactoryTest(_precalculateCreateAddress(_deployer, 0));
    _usdcImplementation = _precalculateCreateAddress(address(factory), 1);
    _usdcProxy = _precalculateCreateAddress(address(factory), 2);
    _l2Adapter = _precalculateCreateAddress(address(factory), 3);
  }

  /**
   * @notice Precalculates the address of a contract that will be deployed thorugh `CREATE` opcode
   * @dev It only works if the for nonces between 0 and 127, which is enough for this use case
   * @param _deployer The deployer address
   * @param _nonce The next nonce of the deployer address
   * @return _precalculatedAddress The address where the contract will be stored
   */
  function _precalculateCreateAddress(
    address _deployer,
    uint256 _nonce
  ) internal pure returns (address _precalculatedAddress) {
    bytes memory data;
    bytes1 len = bytes1(0x94);

    // The integer zero is treated as an empty byte string and therefore has only one length prefix,
    // 0x80, which is calculated via 0x80 + 0.
    if (_nonce == 0x00) {
      data = abi.encodePacked(bytes1(0xd6), len, _deployer, bytes1(0x80));
    }
    // A one-byte integer in the [0x00, 0x7f] range uses its own value as a length prefix, there is no
    // additional "0x80 + length" prefix that precedes it.
    else if (_nonce <= 0x7f) {
      data = abi.encodePacked(bytes1(0xd6), len, _deployer, uint8(_nonce));
    }

    _precalculatedAddress = address(uint160(uint256(keccak256(data))));
  }
}

contract L2OpUSDCFactory_Unit_Constructor is Base {
  event DeployedUSDCImpl(address _usdcImplementation);
  event DeployedUSDCProxy(address _usdcProxy);
  event DeployedL2Adapter(address _l2Adapter);

  /**
   * @notice Check the USDC implementation contract was correctly deployed and the event was emitted
   */
  function test_deployUsdcImplementationAndEmit() public {
    vm.expectEmit(true, true, true, true);
    emit DeployedUSDCImpl(_usdcImplementation);

    vm.prank(_deployer);
    new L2OpUSDCFactoryTest(_usdcProxyInitCode, _usdcImplBytecode, _emptyInitTxs, _l2AdapterBytecode, _emptyInitTxs);

    // Assert the deployed contract has code
    assertGt(_usdcImplementation.code.length, 0);
  }

  /**
   * @notice Check the USDC proxy contract was correctly deployed and the event was emitted
   */
  function test_deployUsdcProxyAndEmit() public {
    vm.expectEmit(true, true, true, true);
    emit DeployedUSDCProxy(_usdcProxy);

    vm.prank(_deployer);
    new L2OpUSDCFactoryTest(_usdcProxyInitCode, _usdcImplBytecode, _emptyInitTxs, _l2AdapterBytecode, _emptyInitTxs);

    // Assert the deployed contract has code
    assertGt(_usdcProxy.code.length, 0);
  }

  /**
   * @notice Check the L2 adapter contract was correctly deployed and the event was emitted
   */
  function test_deployL2AdapterAndEmit() public {
    vm.expectEmit(true, true, true, true);
    emit DeployedL2Adapter(_l2Adapter);

    vm.prank(_deployer);
    new L2OpUSDCFactoryTest(_usdcProxyInitCode, _usdcImplBytecode, _emptyInitTxs, _l2AdapterBytecode, _emptyInitTxs);

    // Assert the deployed contract has code
    assertGt(_l2Adapter.code.length, 0);
  }

  /**
   * @notice Check the USDC implementation calls revert on bad transactions
   */
  function test_revertOnUSDCImplementationBadTxs() public {
    vm.expectRevert(IL2OpUSDCFactory.IL2OpUSDCFactory_UsdcInitializationFailed.selector);
    new L2OpUSDCFactoryTest(_usdcProxyInitCode, _usdcImplBytecode, _badInitTxs, _l2AdapterBytecode, _emptyInitTxs);
  }

  /**
   * @notice Check the USDC implementation initialization transactions were correctly executed
   */
  function test_callUsdcImplementationInitTxs() public {
    vm.expectCall(_usdcImplementation, _initTxs[0]);
    vm.expectCall(_usdcImplementation, _initTxs[1]);

    vm.prank(_deployer);
    new L2OpUSDCFactoryTest(_usdcProxyInitCode, _usdcImplBytecode, _initTxs, _l2AdapterBytecode, _emptyInitTxs);
  }

  /**
   * @notice Check the L2 adapter calls revert on bad transactions
   */
  function test_revertOnL2AdapterBadTxs() public {
    vm.expectRevert(IL2OpUSDCFactory.IL2OpUSDCFactory_AdapterInitializationFailed.selector);
    new L2OpUSDCFactoryTest(_usdcProxyInitCode, _usdcImplBytecode, _emptyInitTxs, _l2AdapterBytecode, _badInitTxs);
  }

  /**
   * @notice Check the L2 adapter initialization transactions were correctly executed
   */
  function test_callL2AdapterInitTxs() public {
    vm.expectCall(_l2Adapter, _initTxOne);
    vm.expectCall(_l2Adapter, _initTxTwo);

    vm.prank(_deployer);
    new L2OpUSDCFactoryTest(_usdcProxyInitCode, _usdcImplBytecode, _emptyInitTxs, _l2AdapterBytecode, _initTxs);
  }
}

contract L2OpUSDCFactory_Unit_CreateDeploy is Base {
  L2OpUSDCFactoryTest _factory;

  function setUp() public override {
    super.setUp();
    // Deploy the factory for the next tests
    _factory =
      new L2OpUSDCFactoryTest(_usdcProxyInitCode, _usdcImplBytecode, _emptyInitTxs, _l2AdapterBytecode, _emptyInitTxs);
  }

  /**
   * @notice Check the factory correctly deploys a new contract through the `CREATE` opcode
   */
  function test_createDeploy() public {
    // Get the init code with the USDC proxy creation code plus the USDC implementation address
    bytes memory _initCode = bytes.concat(_usdcProxyInitCode, abi.encode(_usdcImplementation));
    // Precalculate the address of the contract that will be deployed
    uint256 _nonce = 4;
    address _expectedAddress = _precalculateCreateAddress(address(_factory), _nonce);

    // Execute
    vm.prank(_deployer);
    address _newContract = _factory.forTest_createDeploy(_initCode);

    // Assert the deployed contract has code
    assertEq(_newContract, _expectedAddress);
    assertGt(_newContract.code.length, 0);
  }

  /**
   * @notice Check the factory reverts if the deployment failed
   * @dev It only works with creation code, but not with bytecode so it should revert when using bytecode
   */
  function test_revertIfDeploymentFailed() public {
    vm.expectRevert(IL2OpUSDCFactory.IL2OpUSDCFactory_CreateDeploymentFailed.selector);
    _factory.forTest_createDeploy(_usdcImplBytecode);
  }
}

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
