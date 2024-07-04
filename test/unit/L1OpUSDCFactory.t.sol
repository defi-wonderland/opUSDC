// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {L1OpUSDCBridgeAdapter} from 'contracts/L1OpUSDCBridgeAdapter.sol';
import {IL2OpUSDCFactory} from 'contracts/L1OpUSDCFactory.sol';
import {L1OpUSDCFactory} from 'contracts/L1OpUSDCFactory.sol';
import {L2OpUSDCFactory} from 'contracts/L2OpUSDCFactory.sol';
import {Test} from 'forge-std/Test.sol';
import {IL1OpUSDCFactory} from 'interfaces/IL1OpUSDCFactory.sol';
import {ICreate2Deployer} from 'interfaces/external/ICreate2Deployer.sol';
import {ICrossDomainMessenger} from 'interfaces/external/ICrossDomainMessenger.sol';
import {IUSDC} from 'interfaces/external/IUSDC.sol';
import {CrossChainDeployments} from 'libraries/CrossChainDeployments.sol';
import {Helpers} from 'test/utils/Helpers.sol';

contract ForTestL1OpUSDCFactory is L1OpUSDCFactory {
  constructor(address _usdc) L1OpUSDCFactory(_usdc) {}

  function forTest_precalculateCreateAddress(
    address _deployer,
    uint256 _nonce
  ) public pure returns (address _precalculatedAddress) {
    _precalculatedAddress = CrossChainDeployments.precalculateCreateAddress(_deployer, _nonce);
  }

  function forTest_precalculateCreate2Address(
    bytes32 _salt,
    bytes32 _initCodeHash,
    address _deployer
  ) public pure returns (address _precalculatedAddress) {
    _precalculatedAddress = CrossChainDeployments.precalculateCreate2Address(_salt, _initCodeHash, _deployer);
  }
}

abstract contract Base is Test, Helpers {
  ForTestL1OpUSDCFactory public factory;

  address internal _l2Messenger = 0x4200000000000000000000000000000000000007;
  address internal _l1AdapterOwner = makeAddr('l1AdapterOwner');
  address internal _user = makeAddr('user');
  address internal _usdc = makeAddr('USDC');
  address internal _usdcImplAddress = makeAddr('bridgedUsdcImpl');
  // cant fuzz this because of foundry's VM
  address internal _l1Messenger = makeAddr('messenger');
  address internal _newMasterMinter = makeAddr('newMasterMinter');
  address internal _newPauser = makeAddr('newPauser');
  address internal _newBlacklister = makeAddr('newBlacklister');
  string internal _tokenName = 'Bridged USDC';
  string internal _tokenSymbol = 'USDC.e';
  string internal _tokenCurrency = 'USD';
  uint8 internal _tokenDecimals = 6;

  IL1OpUSDCFactory.L2Deployments internal _l2Deployments;
  bytes[] internal _usdcInitTxs;
  IL2OpUSDCFactory.USDCInitializeData internal _usdcInitializeData;

  function setUp() public virtual {
    // Deploy factory
    factory = new ForTestL1OpUSDCFactory(_usdc);

    // Set the init txs
    bytes memory _initTx = abi.encodeWithSignature('randomCall()');
    _usdcInitTxs.push(_initTx);

    // Define the L2 deployments struct data
    uint32 _minGasLimitFactory = 3_000_000;
    uint32 _minGasLimitDeploy = 8_000_000;
    address _l2AdapterOwner = makeAddr('l2AdapterOwner');
    bytes memory _usdcImplementationInitCode = '0x6080333333';
    _l2Deployments = IL1OpUSDCFactory.L2Deployments({
      l2AdapterOwner: _l2AdapterOwner,
      usdcImplementationInitCode: _usdcImplementationInitCode,
      usdcInitTxs: _usdcInitTxs,
      minGasLimitFactory: _minGasLimitFactory,
      minGasLimitDeploy: _minGasLimitDeploy
    });

    _usdcInitializeData = IL2OpUSDCFactory.USDCInitializeData({
      tokenName: _tokenName,
      tokenSymbol: _tokenSymbol,
      tokenCurrency: _tokenCurrency,
      tokenDecimals: _tokenDecimals
    });
  }

  /**
   * @notice Helper function to mock all the function calls that will be made in the `deploy` function,
   * and some that will be made in the `deploy` function
   */
  function _mockDeployCalls() internal {
    // Mock the call over the `portal` function on the L1 messenger
    vm.mockCall(_l1Messenger, abi.encodeWithSelector(ICrossDomainMessenger.sendMessage.selector), abi.encode(''));

    // Mock the call over USDC `currency` function
    vm.mockCall(_usdc, abi.encodeWithSelector(IUSDC.currency.selector), abi.encode(_tokenCurrency));

    // Mock the call over USDC `decimals` function
    vm.mockCall(_usdc, abi.encodeWithSelector(IUSDC.decimals.selector), abi.encode(_tokenDecimals));
  }
}

contract L1OpUSDCFactory_Unit_Constructor is Base {
  /**
   * @notice Test the constructor params are correctly set
   */
  function test_setImmutables() public view {
    // Assert
    assertEq(address(factory.USDC()), _usdc, 'Invalid usdc address');
  }
}

contract L1OpUSDCFactory_Unit_Deploy is Base {
  event L1AdapterDeployed(address _l1Adapter);

  /**
   * @notice Check the function reverts if the `initialize()` tx is the first init tx
   */
  function test_revertOnInitializeTx() public {
    vm.expectRevert(IL1OpUSDCFactory.IL1OpUSDCFactory_NoInitializeTx.selector);

    // Set the `initialize(string,string,string,uint8,address,address,address,address)` tx as the first init tx
    bytes memory _initializeSelector = abi.encodePacked(IUSDC.initialize.selector);
    _usdcInitTxs[0] = _initializeSelector;
    _l2Deployments.usdcInitTxs = _usdcInitTxs;

    // Execute
    vm.prank(_user);
    factory.deploy(_l1Messenger, _l1AdapterOwner, _l2Deployments);
  }

  /**
   * @notice Check the salt counter is incremented by 1 after the `deploy` function is called
   */
  function test_incrementSalt() public {
    uint256 _saltBefore = factory.deploymentsSaltCounter();

    _mockDeployCalls();

    // Execute
    vm.prank(_user);
    factory.deploy(_l1Messenger, _l1AdapterOwner, _l2Deployments);

    // Assert
    assertEq(factory.deploymentsSaltCounter(), _saltBefore + 1, 'Invalid salt counter');
  }

  /**
   * @notice Check the function deploys the L1 adapter correctly
   * @dev Assuming the `L1OpUSDCBridgeAdapter` sets the immutables correctly to check we are passing the right values
   */
  function test_deployL1Adapter() public {
    bytes32 _salt = bytes32(factory.deploymentsSaltCounter() + 1);

    // Calculate the L1 Adapter address
    address _l1Adapter = factory.forTest_precalculateCreateAddress(address(factory), vm.getNonce(address(factory)));

    // Calculate the l2 factory address
    bytes memory _l2FactoryCArgs = abi.encode(address(factory), _l2Messenger, _l1Adapter);
    bytes memory _l2FactoryInitCode = bytes.concat(type(L2OpUSDCFactory).creationCode, _l2FactoryCArgs);
    address _l2Factory =
      factory.forTest_precalculateCreate2Address(_salt, keccak256(_l2FactoryInitCode), factory.L2_CREATE2_DEPLOYER());

    // Calculate the L2 adapter address
    address _l2Adapter = factory.forTest_precalculateCreateAddress(_l2Factory, 3);

    // Mock all the `deploy` function calls
    _mockDeployCalls();

    // Execute
    vm.prank(_user);
    factory.deploy(_l1Messenger, _l1AdapterOwner, _l2Deployments);

    // Assert the contract was deployed by checking its bytecode length is greater than 0
    assertGt(_l1Adapter.code.length, 0, 'L1 adapter not deployed');
    // Check the constructor values were properly passed
    assertEq(L1OpUSDCBridgeAdapter(_l1Adapter).USDC(), _usdc, 'Invalid USDC address');
    assertEq(L1OpUSDCBridgeAdapter(_l1Adapter).MESSENGER(), _l1Messenger, 'Invalid messenger address');
    assertEq(L1OpUSDCBridgeAdapter(_l1Adapter).LINKED_ADAPTER(), _l2Adapter, 'Invalid linked adapter address');
    assertEq(L1OpUSDCBridgeAdapter(_l1Adapter).owner(), _l1AdapterOwner, 'Invalid owner address');
  }

  /**
   * @notice Check it calls the `currency` function on the USDC contract
   */
  function test_callUsdcCurrency() public {
    // Mock all the `deploy` function calls
    _mockDeployCalls();

    // Expect the `name` function to be called
    vm.expectCall(_usdc, abi.encodeWithSelector(IUSDC.currency.selector));

    // Execute
    vm.prank(_user);
    factory.deploy(_l1Messenger, _l1AdapterOwner, _l2Deployments);
  }

  /**
   * @notice Check it calls the `decimals` function on the USDC contract
   */
  function test_callUsdcDecimals() public {
    // Mock all the `deploy` function calls
    _mockDeployCalls();

    // Expect the `name` function to be called
    vm.expectCall(_usdc, abi.encodeWithSelector(IUSDC.decimals.selector));

    // Execute
    vm.prank(_user);
    factory.deploy(_l1Messenger, _l1AdapterOwner, _l2Deployments);
  }

  /**
   * @notice Check the `deploy` call over the `create2Deployer` is correctly sent through the messenger
   */
  function test_sendFactoryDeploymentMessage() public {
    uint256 _zeroValue = 0;
    bytes32 _salt = bytes32(factory.deploymentsSaltCounter() + 1);

    // Mock all the `deploy` function calls
    _mockDeployCalls();

    // Precalculate the L1 adapter address
    uint256 _factoryNonce = vm.getNonce(address(factory));
    address _l1Adapter = factory.forTest_precalculateCreateAddress(address(factory), _factoryNonce);

    // Get the L2 factory deployment tx
    bytes memory _l2FactoryCArgs = abi.encode(address(factory), _l2Messenger, _l1Adapter);
    bytes memory _l2FactoryInitCode = bytes.concat(type(L2OpUSDCFactory).creationCode, _l2FactoryCArgs);
    bytes memory _l2FactoryCreate2Tx =
      abi.encodeWithSelector(ICreate2Deployer.deploy.selector, _zeroValue, _salt, _l2FactoryInitCode);

    // Expect the `sendMessage` to be properly called
    vm.expectCall(
      _l1Messenger,
      abi.encodeWithSelector(
        ICrossDomainMessenger.sendMessage.selector,
        factory.L2_CREATE2_DEPLOYER(),
        _l2FactoryCreate2Tx,
        _l2Deployments.minGasLimitFactory
      )
    );

    // Execute
    vm.prank(_user);
    factory.deploy(_l1Messenger, _l1AdapterOwner, _l2Deployments);
  }

  /**
   * @notice Check the `deploy` call over the L2 Factory is correctly sent through the messenger
   */
  function test_sendDeployMessage() public {
    bytes32 _salt = bytes32(factory.deploymentsSaltCounter() + 1);

    // Mock all the `deploy` function calls
    _mockDeployCalls();

    // Precalculate the l1 adapter address
    address _l1Adapter = factory.forTest_precalculateCreateAddress(address(factory), vm.getNonce(address(factory)));

    // Get the L2 factory init code
    bytes memory _l2FactoryCArgs = abi.encode(address(factory), _l2Messenger, _l1Adapter);
    bytes memory _l2FactoryInitCode = bytes.concat(type(L2OpUSDCFactory).creationCode, _l2FactoryCArgs);
    bytes memory _l2FactoryDeployTx = abi.encodeWithSelector(
      IL2OpUSDCFactory.deploy.selector,
      _l2Deployments.l2AdapterOwner,
      _l2Deployments.usdcImplementationInitCode,
      _usdcInitializeData,
      _l2Deployments.usdcInitTxs
    );
    // Precalculate its address
    address _l2Factory =
      factory.forTest_precalculateCreate2Address(_salt, keccak256(_l2FactoryInitCode), factory.L2_CREATE2_DEPLOYER());

    // Expect the `sendMessage` to be properly called
    vm.expectCall(
      _l1Messenger,
      abi.encodeWithSelector(
        ICrossDomainMessenger.sendMessage.selector, _l2Factory, _l2FactoryDeployTx, _l2Deployments.minGasLimitDeploy
      )
    );

    // Execute
    vm.prank(_user);
    factory.deploy(_l1Messenger, _l1AdapterOwner, _l2Deployments);
  }

  /**
   * @notice Check the `L1AdapterDeployed` event is properly emitted
   */
  function test_emitEvent() public {
    // Calculate the l1 adapter address
    uint256 _factoryNonce = vm.getNonce(address(factory));
    address _l1Adapter = factory.forTest_precalculateCreateAddress(address(factory), _factoryNonce);

    // Mock all the `deploy` function calls
    _mockDeployCalls();

    // Expect the `L1AdapterDeployed` event to be emitted
    vm.expectEmit(true, true, true, true);
    emit L1AdapterDeployed(_l1Adapter);

    // Execute
    vm.prank(_user);
    factory.deploy(_l1Messenger, _l1AdapterOwner, _l2Deployments);
  }

  /**
   * @notice Check the returned addresses are the expected ones
   */
  function test_returnAdapters() public {
    bytes32 _salt = bytes32(factory.deploymentsSaltCounter() + 1);

    // Calculate the L1 Adapter address
    address _expectedL1Adapter =
      factory.forTest_precalculateCreateAddress(address(factory), vm.getNonce(address(factory)));

    // Calculate the l2 factory address
    bytes memory _l2FactoryCArgs = abi.encode(address(factory), _l2Messenger, _expectedL1Adapter);
    bytes memory _l2FactoryInitCode = bytes.concat(type(L2OpUSDCFactory).creationCode, _l2FactoryCArgs);
    address _expectedL2Factory =
      factory.forTest_precalculateCreate2Address(_salt, keccak256(_l2FactoryInitCode), factory.L2_CREATE2_DEPLOYER());

    // Calculate the L2 adapter address
    address _expectedL2Adapter = factory.forTest_precalculateCreateAddress(_expectedL2Factory, 3);

    // Mock all the `deploy` function calls
    _mockDeployCalls();

    // Execute
    (address _l1Adapter, address _l2Factory, address _l2Adapter) =
      factory.deploy(_l1Messenger, _l1AdapterOwner, _l2Deployments);

    // Assert
    assertEq(_l1Adapter, _expectedL1Adapter, 'Invalid l1 adapter address');
    assertEq(_l2Factory, _expectedL2Factory, 'Invalid l2 factory address');
    assertEq(_l2Adapter, _expectedL2Adapter, 'Invalid l2 adapter address');
  }
}

contract L1OpUSDCFactory_Unit_PrecalculateCreateAddress is Base {
  /**
   * @notice Check the `precalculateCreateAddress` function returns the correct address for the given deployer and nonce
   * We are testing the range from 1 to (2**64 -2)
   */
  function test_precalculateCreateAddress(address _deployer, uint256 _nonce) public {
    uint256 _maxNonce = 2 ** 64 - 2;
    _nonce = bound(_nonce, 1, _maxNonce);
    // Setting a lower nonce than the deployer's current one will revert
    vm.assume(vm.getNonce(_deployer) <= _nonce);
    vm.setNonce(_deployer, uint64(_nonce));

    // Precalculate the address
    address _precalculatedAddress = factory.forTest_precalculateCreateAddress(_deployer, _nonce);

    // Execute
    vm.prank(_deployer);
    address _newAddress = address(new ForTest_DummyContract());

    // Assert
    assertEq(_newAddress, _precalculatedAddress, 'Invalid create precalculated address');
  }
}

contract L1OpUSDCFactory_Unit_PrecalculateCreate2Address is Base {
  // Error to revert when the create2 fails while testing the precalculateCreate2Address function
  error ForTest_Create2Failed();

  /**
   * @notice Check the function returns the expected address
   */
  function test_precalculateCreate2Address(bytes32 _salt, address _deployer) public {
    // Get the dumy contract init code and its hash
    bytes memory _initCode = type(ForTest_DummyContract).creationCode;
    bytes32 _initCodeHash = keccak256(_initCode);

    // Precalculate the address
    address _precalculatedAddress = factory.forTest_precalculateCreate2Address(_salt, _initCodeHash, _deployer);
    address _newAddress;

    // Deploy the contract using the CREATE2 opcode
    vm.prank(_deployer);
    assembly ("memory-safe") {
      _newAddress := create2(callvalue(), add(_initCode, 0x20), mload(_initCode), _salt)
    }
    if (_newAddress == address(0) || _newAddress.code.length == 0) {
      revert ForTest_Create2Failed();
    }

    // Assert the address is the expected one
    assertEq(_newAddress, _precalculatedAddress, 'Invalid create2 precalculated address');
  }
}

/**
 * @notice Dummy contract to be deployed only for testing purposes
 */
contract ForTest_DummyContract {}
