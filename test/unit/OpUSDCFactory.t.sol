// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {L1OpUSDCBridgeAdapter} from 'contracts/L1OpUSDCBridgeAdapter.sol';
import {L2OpUSDCBridgeAdapter} from 'contracts/L2OpUSDCBridgeAdapter.sol';
import {OpUSDCFactory} from 'contracts/OpUSDCFactory.sol';
import {USDCInitTxs} from 'contracts/utils/USDCInitTxs.sol';
import {Test} from 'forge-std/Test.sol';
import {IOpUSDCFactory} from 'interfaces/IOpUSDCFactory.sol';
import {ICreateX} from 'interfaces/external/ICreateX.sol';
import {ICrossDomainMessenger} from 'interfaces/external/ICrossDomainMessenger.sol';
import {Helpers} from 'test/utils/Helpers.sol';

contract OpUSDCFactoryForTest is OpUSDCFactory {
  constructor(address _usdc, address _createX, uint256 _salt) OpUSDCFactory(_usdc, _createX, _salt) {}

  function forTest_parseSalt(address _sender, uint256 _salt) external pure returns (bytes32 _parsedSalt) {
    _parsedSalt = _parseSalt(_sender, _salt);
  }

  function forTest_getGuardedSalt(
    address _sender,
    uint256 _chainId,
    bytes32 _salt
  ) external pure returns (bytes32 _guardedSalt) {
    _guardedSalt = _getGuardedSalt(_sender, _chainId, _salt);
  }
}

abstract contract Base is Test, Helpers {
  OpUSDCFactoryForTest public factory;

  address internal _owner = makeAddr('owner');
  address internal _user = makeAddr('user');
  address internal _usdc = makeAddr('USDC');
  address internal _l1Messenger = makeAddr('l1Messenger');
  address internal _l2Messenger = makeAddr('l2Messenger');
  address internal _l1Adapter = makeAddr('l1Adapter');
  address internal _l2Adapter = makeAddr('l2Adapter');
  address internal _createX = makeAddr('createX');
  address _l2UsdcProxyAddress = makeAddr('l2UsdcProxyAddress');
  address _l2UsdcImplAddress = makeAddr('l2UsdcImplAddress');
  address _l1AdapterAddress = makeAddr('l1AdapterAddress');
  address _l2AdapterAddress = makeAddr('l2AdapterAddress');
  uint32 internal _minGasLimitUsdcImplementationDeploy = 1000;
  uint32 internal _minGasLimitUsdcProxyDeploy = 2000;
  uint32 internal _minGasLimitL2AdapterDeploy = 3000;
  bytes internal _l1AdapterCreationCode = '0x608060809090';
  bytes internal _l2AdapterCreationCode = '0x608060802020';
  bytes internal _usdcProxyCreationCode = '0x608060803030';
  bytes internal _usdcImplementationCreationCode = '0x608040601010';
  uint32 internal _minGasLimitInitTxs = 4000;
  uint256 internal _l2ChainId = block.chainid;
  uint256 internal _inputSalt = 1234;
  bytes32 internal _saltL1;
  bytes32 internal _saltL2;
  bytes32 internal _guardedSaltL1;
  bytes32 internal _guardedSaltL2;

  IOpUSDCFactory.DeployParams internal _params;

  function setUp() public {
    // Deploy factory
    factory = new OpUSDCFactoryForTest(_usdc, _createX, _inputSalt);
    // Define the params to call the `deploy()` function
    _params = IOpUSDCFactory.DeployParams({
      l1Messenger: ICrossDomainMessenger(_l1Messenger),
      l2Messenger: _l2Messenger,
      l1AdapterCreationCode: _l1AdapterCreationCode,
      l2AdapterCreationCode: _l2AdapterCreationCode,
      usdcProxyCreationCode: _usdcProxyCreationCode,
      usdcImplementationCreationCode: _usdcImplementationCreationCode,
      owner: _owner,
      minGasLimitUsdcImplementationDeploy: _minGasLimitUsdcImplementationDeploy,
      minGasLimitUsdcProxyDeploy: _minGasLimitUsdcProxyDeploy,
      minGasLimitL2AdapterDeploy: _minGasLimitL2AdapterDeploy,
      minGasLimitInitTxs: _minGasLimitInitTxs,
      l2ChainId: _l2ChainId
    });
    _saltL1 = factory.SALT_L1();
    _guardedSaltL1 = factory.GUARDED_SALT_L1();
    // Get the SALT for L2 deployment and calculate its guarded salt
    _saltL2 = factory.forTest_parseSalt(_params.l2Messenger, uint256(_saltL1));
    _guardedSaltL2 = factory.forTest_getGuardedSalt(_params.l2Messenger, _params.l2ChainId, _saltL2);
  }

  function _mockAllDeployCalls() public {
    // Mock call over compute usdc implementation address

    vm.mockCall(
      _createX,
      abi.encodeWithSignature(
        'computeCreate2Address(bytes32,bytes32,address)',
        _guardedSaltL2,
        keccak256(_params.usdcImplementationCreationCode),
        address(_createX)
      ),
      abi.encode(_l2UsdcImplAddress)
    );

    // Mock and expect call over compute usdc proxy address
    bytes memory _usdcProxyInitCode = bytes.concat(_params.usdcProxyCreationCode, abi.encode(_l2UsdcImplAddress));

    vm.mockCall(
      _createX,
      abi.encodeWithSignature(
        'computeCreate2Address(bytes32,bytes32,address)', _guardedSaltL2, keccak256(_usdcProxyInitCode), _createX
      ),
      abi.encode(_l2UsdcProxyAddress)
    );

    // Mock call over compute l1 linked adapter address
    vm.mockCall(
      _createX,
      abi.encodeWithSignature('computeCreate3Address(bytes32,address)', _guardedSaltL1, address(_createX)),
      abi.encode(_l1AdapterAddress)
    );

    // Mock call over compute l2 linked adaper address
    bytes memory _l2AdapterCArgs = abi.encode(_l2UsdcProxyAddress, _params.l2Messenger, _l1AdapterAddress);
    bytes memory _l2AdapterInitCode = bytes.concat(_params.l2AdapterCreationCode, _l2AdapterCArgs);
    vm.mockCall(
      _createX,
      abi.encodeWithSignature(
        'computeCreate2Address(bytes32,bytes32,address)', _guardedSaltL2, keccak256(_l2AdapterInitCode), _createX
      ),
      abi.encode((_l2AdapterAddress))
    );
    // Mock messaging calls
    vm.mockCall(_l1Messenger, abi.encodeWithSignature('sendMessage(address,bytes,uint32)'), abi.encode(true));

    // Mock call over deployCreate3
    vm.mockCall(_createX, abi.encodeWithSignature('deployCreate3(bytes32,bytes)'), abi.encode(_l1AdapterAddress));
  }
}

contract OpUSDCFactory_Unit_Constructor is Base {
  function test_constructorParams() public {
    assertEq(factory.USDC(), _usdc, 'USDC should be set');
    assertEq(address(factory.CREATEX()), _createX, 'CREATEX should be set');
    bytes32 _parsedSalt = factory.forTest_parseSalt(address(factory), _inputSalt);
    assertEq(factory.SALT_L1(), _parsedSalt, 'SALT should be set');
    bytes32 _guardedSalt = factory.forTest_getGuardedSalt(address(factory), _l2ChainId, _parsedSalt);
    assertEq(factory.GUARDED_SALT_L1(), _guardedSalt, 'GUARDED_SALT should be set');
  }
}

contract OpUSDCFactory_Unit_Deploy is Base {
  function test_callComputeUsdcImplAddress() public {
    // Mock and expect call over compute usdc implementation address
    address _l2UsdcImplAddress = makeAddr('l2UsdcImplAddress');
    _mockAndExpect(
      _createX,
      abi.encodeWithSignature(
        'computeCreate2Address(bytes32,bytes32,address)',
        _guardedSaltL2,
        keccak256(_params.usdcImplementationCreationCode),
        address(_createX)
      ),
      abi.encode(_l2UsdcImplAddress)
    );

    // Mock the rest of the calls
    _mockAllDeployCalls();

    // Execute
    vm.prank(_user);
    factory.deploy(_params);
  }

  function test_callComputeUsdcProxyAddress() public {
    // Mock and expect call over compute usdc proxy address
    address _l2UsdcProxyAddress = makeAddr('l2UsdcProxyAddress');
    bytes memory _usdcProxyInitCode = bytes.concat(_params.usdcProxyCreationCode, abi.encode(_l2UsdcImplAddress));

    _mockAndExpect(
      _createX,
      abi.encodeWithSignature(
        'computeCreate2Address(bytes32,bytes32,address)', _guardedSaltL2, keccak256(_usdcProxyInitCode), _createX
      ),
      abi.encode(_l2UsdcProxyAddress)
    );

    _mockAllDeployCalls();

    // Execute
    vm.prank(_user);
    factory.deploy(_params);
  }

  function test_callComputeL1AdapterAddress() public {
    // Mock call over compute l1 linked adapter address
    address _l1AdapterAddress = makeAddr('l1AdapterAddress');
    _mockAndExpect(
      _createX,
      abi.encodeWithSignature('computeCreate3Address(bytes32,address)', _guardedSaltL1, address(_createX)),
      abi.encode(_l1AdapterAddress)
    );

    // Mock the rest of the calls
    _mockAllDeployCalls();

    // Execute
    vm.prank(_user);
    factory.deploy(_params);
  }

  function test_callComputeL2AdapterAddress() public {
    // Mock call over compute l2 linked adaper address
    address _l2AdapterAddress = makeAddr('l2AdapterAddress');
    bytes memory _l2AdapterCArgs = abi.encode(_l2UsdcProxyAddress, _params.l2Messenger, _l1AdapterAddress);
    bytes memory _l2AdapterInitCode = bytes.concat(_params.l2AdapterCreationCode, _l2AdapterCArgs);
    _mockAndExpect(
      _createX,
      abi.encodeWithSignature(
        'computeCreate2Address(bytes32,bytes32,address)', _guardedSaltL2, keccak256(_l2AdapterInitCode), _createX
      ),
      abi.encode((_l2AdapterAddress))
    );

    // Mock the rest of the calls
    _mockAllDeployCalls();

    // Execute
    vm.prank(_user);
    factory.deploy(_params);
  }

  function test_callSendUsdcImplDeployMsg() public {
    // Mock and expect call over usdc implementation message sent
    bytes memory _usdcImplementationDeployTx =
      abi.encodeWithSignature('deployCreate2(bytes32,bytes)', _saltL2, _params.usdcImplementationCreationCode);
    _mockAndExpect(
      _l1Messenger,
      abi.encodeWithSignature(
        'sendMessage(address,bytes,uint32)', _createX, _usdcImplementationDeployTx, _minGasLimitUsdcImplementationDeploy
      ),
      abi.encode(true)
    );

    // Mock the rest of the calls
    _mockAllDeployCalls();

    // Execute
    vm.prank(_user);
    factory.deploy(_params);
  }

  function test_callSendUsdcImplInitializeMsg() public {
    // Mock and expect call over usdc implementation message sent
    _mockAndExpect(
      _l1Messenger,
      abi.encodeWithSignature(
        'sendMessage(address,bytes,uint32)', _l2UsdcImplAddress, USDCInitTxs.INITIALIZE, _minGasLimitInitTxs
      ),
      abi.encode(true)
    );

    // Mock the rest of the calls
    _mockAllDeployCalls();

    // Execute
    vm.prank(_user);
    factory.deploy(_params);
  }

  function test_callSendUsdcImplInitializeV2Msg() public {
    // Mock and expect call over usdc implementation message sent
    _mockAndExpect(
      _l1Messenger,
      abi.encodeWithSignature(
        'sendMessage(address,bytes,uint32)', _l2UsdcImplAddress, USDCInitTxs.INITIALIZEV2, _minGasLimitInitTxs
      ),
      abi.encode(true)
    );

    // Mock the rest of the calls
    _mockAllDeployCalls();

    // Execute
    vm.prank(_user);
    factory.deploy(_params);
  }

  function test_callSendUsdcImplInitializeV2_1Msg() public {
    // Mock and expect call over usdc implementation message sent
    _mockAndExpect(
      _l1Messenger,
      abi.encodeWithSignature(
        'sendMessage(address,bytes,uint32)', _l2UsdcImplAddress, USDCInitTxs.INITIALIZEV2_1, _minGasLimitInitTxs
      ),
      abi.encode(true)
    );

    // Mock the rest of the calls
    _mockAllDeployCalls();

    // Execute
    vm.prank(_user);
    factory.deploy(_params);
  }

  function test_callSendUsdcImplInitializeV2_2Msg() public {
    // Mock and expect call over usdc implementation message sent
    _mockAndExpect(
      _l1Messenger,
      abi.encodeWithSignature(
        'sendMessage(address,bytes,uint32)', _l2UsdcImplAddress, USDCInitTxs.INITIALIZEV2_2, _minGasLimitInitTxs
      ),
      abi.encode(true)
    );

    // Mock the rest of the calls
    _mockAllDeployCalls();

    // Execute
    vm.prank(_user);
    factory.deploy(_params);
  }

  function test_callSendUsdcProxyDeployMsg() public {
    // Expect the deploy usdc message to be correctly sent
    bytes memory _usdcProxyInitCode = bytes.concat(_params.usdcProxyCreationCode, abi.encode(_l2UsdcImplAddress));
    bytes memory _usdcDeployProxyTx =
      abi.encodeWithSignature('deployCreate2(bytes32,bytes)', _saltL2, _usdcProxyInitCode);
    _mockAndExpect(
      _l1Messenger,
      abi.encodeWithSignature(
        'sendMessage(address,bytes,uint32)', _createX, _usdcDeployProxyTx, _minGasLimitUsdcProxyDeploy
      ),
      abi.encode(true)
    );

    // Mock the rest of the calls
    _mockAllDeployCalls();

    // Execute
    vm.prank(_user);
    factory.deploy(_params);
  }

  function test_callSendL2AdapterDeployMsg() public {
    // Expect the deploy l2 adapter message to be correctly sent
    bytes memory _l2AdapterCArgs = abi.encode(_l2UsdcProxyAddress, _params.l2Messenger, _l1AdapterAddress);
    bytes memory _l2AdapterInitCode = bytes.concat(_params.l2AdapterCreationCode, _l2AdapterCArgs);
    bytes memory _l2AdapterDeployTx =
      abi.encodeWithSignature('deployCreate2(bytes32,bytes)', _saltL2, _l2AdapterInitCode);
    _mockAndExpect(
      _l1Messenger,
      abi.encodeWithSignature(
        'sendMessage(address,bytes,uint32)', _createX, _l2AdapterDeployTx, _minGasLimitL2AdapterDeploy
      ),
      abi.encode(true)
    );

    // Mock the rest of the calls
    _mockAllDeployCalls();

    // Execute
    vm.prank(_user);
    factory.deploy(_params);
  }

  function test_callDeployCreate3() public {
    // Mock the rest of the calls
    _mockAllDeployCalls();

    // Expect the deploy l1 adapter message to be correctly sent
    // address _l1AdapterAddress = makeAddr('l1AdapterAddress');
    bytes memory _l1AdapterCArgs = abi.encode(_usdc, _params.l1Messenger, _l2AdapterAddress, _owner);
    bytes memory _l1AdapterInitCode = bytes.concat(_params.l1AdapterCreationCode, _l1AdapterCArgs);
    _mockAndExpect(
      _createX,
      abi.encodeWithSignature('deployCreate3(bytes32,bytes)', _saltL1, _l1AdapterInitCode),
      abi.encode(_l1AdapterAddress)
    );

    // Execute
    vm.prank(_user);
    factory.deploy(_params);
  }
}

contract OpUSDCFactory_Unit_ParseSalt is Base {
  function test_parseSalt(address _sender, uint256 _inputSalt) public {
    // Calculate the expected salt
    bytes32 _senderToBytes = bytes32(uint256(uint160(_sender)) << 96);
    bytes32 _maskedSalt = bytes32(_inputSalt & 0x000000000000000000000000000000000000000000ffffffffffffffffffff);
    bytes32 _expectedParsedSalt = _senderToBytes | factory.REDEPLOY_PROTECTION_BYTE() | _maskedSalt;

    // Execute
    bytes32 _returnedParsedSalt = factory.forTest_parseSalt(_sender, _inputSalt);
    assertEq(_returnedParsedSalt, _expectedParsedSalt, 'Parsed salts differ');
  }
}

contract OpUSDCFactory_Unit_GetGuardedSalt is Base {
  function test_getGuardedSalt(address _sender, uint256 _chainId, bytes32 _inputSalt) public {
    // Calculate the expected guarded salt
    bytes32 _expectedGuardedSalt = keccak256(abi.encode(_sender, _chainId, _inputSalt));

    // Execute
    bytes32 _returnedGuardedSalt = factory.forTest_getGuardedSalt(_sender, _chainId, _inputSalt);
    assertEq(_returnedGuardedSalt, _expectedGuardedSalt, 'Guarded salts differ');
  }
}
