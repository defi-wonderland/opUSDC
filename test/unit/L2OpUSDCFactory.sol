// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {L1OpUSDCBridgeAdapter} from 'contracts/L1OpUSDCBridgeAdapter.sol';
import {L1OpUSDCFactory} from 'contracts/L1OpUSDCFactory.sol';

import {L2OpUSDCBridgeAdapter} from 'contracts/L2OpUSDCBridgeAdapter.sol';

import {L2OpUSDCFactory} from 'contracts/L2OpUSDCFactory.sol';
import {UpgradeManager} from 'contracts/UpgradeManager.sol';
import {USDCInitTxs} from 'contracts/utils/USDCInitTxs.sol';
import {USDC_PROXY_CREATION_CODE} from 'contracts/utils/USDCProxyCreationCode.sol';
import {Test} from 'forge-std/Test.sol';
import {IL1OpUSDCFactory} from 'interfaces/IL1OpUSDCFactory.sol';
import {IL2OpUSDCFactory} from 'interfaces/IL2OpUSDCFactory.sol';
import {IUpgradeManager} from 'interfaces/IUpgradeManager.sol';
import {ICrossDomainMessenger} from 'interfaces/external/ICrossDomainMessenger.sol';
import {IOptimismPortal} from 'interfaces/external/IOptimismPortal.sol';
import {AddressAliasHelper} from 'test/utils/AddressAliasHelper.sol';
import {Helpers} from 'test/utils/Helpers.sol';

import 'forge-std/Test.sol';

contract L2OpUSDCFactoryTest is L2OpUSDCFactory {
  constructor(
    bytes memory _usdcProxyInitCode,
    bytes memory _usdcImplBytecode,
    bytes[] memory _usdcImplInitTxs,
    bytes memory _l2AdapterBytecode,
    bytes[] memory _l2AdapterInitTxs
  ) L2OpUSDCFactory(_usdcProxyInitCode, _usdcImplBytecode, _usdcImplInitTxs, _l2AdapterBytecode, _l2AdapterInitTxs) {}

  function createDeploy(bytes memory _initCode) public returns (address _newContract) {
    _newContract = _createDeploy(_initCode);
  }
}

contract Base is Test, Helpers {
  address public factory;

  address internal _deployer = makeAddr('deployer');
  bytes internal _usdcProxyInitCode;
  bytes internal _usdcImplBytecode;
  bytes internal _l2AdapterBytecode;
  address internal _usdcImplementation;
  address internal _usdcProxy;
  address internal _l2Adapter;

  bytes internal _bytecode;
  bytes[] internal _emptyInitTxs;
  bytes[] internal _initTxs;
  bytes[] internal _badInitTxs;

  function setUp() public virtual {
    address _dummyContract = address(new ForTestDummyContract());
    _bytecode = _dummyContract.code;
    _usdcProxyInitCode = type(ForTestDummyContract).creationCode;

    bytes memory _initTxOne = abi.encodeWithSignature('dummyFunction()');
    bytes memory _initTxTwo = abi.encodeWithSignature('dummyFunctionTwo()');
    _initTxs = new bytes[](2);
    _initTxs[0] = _initTxOne;
    _initTxs[1] = _initTxTwo;

    bytes memory _badInitTx = abi.encodeWithSignature('nonExistentFunction()');
    _badInitTxs = new bytes[](1);
    _badInitTxs[0] = _badInitTx;

    factory = _precalculateCreateAddress(_deployer, 0);
    _usdcImplementation = _precalculateCreateAddress(factory, 1);
    _usdcProxy = _precalculateCreateAddress(factory, 2);
    _l2Adapter = _precalculateCreateAddress(factory, 3);

    console.log('factory: ', factory);
    console.log('usdc implementation: ', _usdcImplementation);
    console.log('usdc proxy: ', _usdcProxy);
    console.log('l2 adapter: ', _l2Adapter);
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

  function test_deployUsdcImplementationAndEmit() public {
    console.log('usdc implementation address: ', _usdcImplementation);

    vm.expectEmit(true, true, true, true);
    emit DeployedUSDCImpl(_usdcImplementation);

    vm.prank(_deployer);
    new L2OpUSDCFactoryTest(_usdcProxyInitCode, _usdcImplBytecode, _emptyInitTxs, _l2AdapterBytecode, _emptyInitTxs);

    // Assert the deployed contract has code
    assertGt(_usdcImplementation.code.length, 0);
  }

  function test_deployUsdcProxyAndEmit() public {
    console.log('usdc proxy address: ', _usdcProxy);

    vm.expectEmit(true, true, true, true);
    emit DeployedUSDCProxy(_usdcProxy);

    vm.prank(_deployer);
    new L2OpUSDCFactoryTest(_usdcProxyInitCode, _usdcImplBytecode, _emptyInitTxs, _l2AdapterBytecode, _emptyInitTxs);

    // Assert the deployed contract has code
    assertGt(_usdcProxy.code.length, 0);
  }

  function test_deployL2AdapterAndEmit() public {
    console.log('l2 adapter address: ', _l2Adapter);

    vm.expectEmit(true, true, true, true);
    emit DeployedL2Adapter(_l2Adapter);

    vm.prank(_deployer);
    new L2OpUSDCFactoryTest(_usdcProxyInitCode, _usdcImplBytecode, _emptyInitTxs, _l2AdapterBytecode, _emptyInitTxs);

    // Assert the deployed contract has code
    assertGt(_l2Adapter.code.length, 0);
  }

  function test_callUsdcImplementationInitTxs() public {
    // vm.mockCall(_usdcImplementation, _initTxs[0], abi.encode(true));
    // vm.mockCall(_usdcImplementation, _initTxs[1], abi.encode(true));

    vm.prank(_deployer);
    new L2OpUSDCFactoryTest(_usdcProxyInitCode, _usdcImplBytecode, _initTxs, _l2AdapterBytecode, _emptyInitTxs);
  }

  function test_callL2AdapterInitTxs() public {
    // vm.mockCall(_l2Adapter, _initTxs[0], abi.encode(true));
    // vm.mockCall(_l2Adapter, _initTxs[1], abi.encode(true));

    vm.prank(_deployer);
    new L2OpUSDCFactoryTest(_usdcProxyInitCode, _usdcImplBytecode, _emptyInitTxs, _l2AdapterBytecode, _initTxs);
  }
}

contract L2OpUSDCFactory_Unit_CreateDeploy is Base {
  L2OpUSDCFactoryTest _factory;

  function setUp() public override {
    super.setUp();
    _factory =
      new L2OpUSDCFactoryTest(_usdcProxyInitCode, _usdcImplBytecode, _emptyInitTxs, _l2AdapterBytecode, _emptyInitTxs);
  }

  function test_createDeploy(address _usdcImplementation) public {
    vm.prank(_deployer);

    bytes memory _initCode = bytes.concat(_usdcProxyInitCode, abi.encode(_usdcImplementation));
    uint256 _nonce = 4;
    address _expectedAddress = _precalculateCreateAddress(address(_factory), _nonce);
    address _newContract = _factory.createDeploy(_initCode);

    // Assert the deployed contract has code
    assertEq(_newContract, _expectedAddress);
    assertGt(_newContract.code.length, 0);
  }

  function test_revertIfDeploymentFailed() public {
    // It only works with creation code, but not with bytecode
    vm.expectRevert(IL2OpUSDCFactory.IL2OpUSDCFactory_CreateDeploymentFailed.selector);
    _factory.createDeploy(_bytecode);
  }
}

contract ForTestDummyContract {
  function dummyFunction() public pure returns (bool) {
    return true;
  }

  function dummyFunctionTwo() public pure returns (bool) {
    return true;
  }
}
