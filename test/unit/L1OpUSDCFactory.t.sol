// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {L1OpUSDCBridgeAdapter} from 'contracts/L1OpUSDCBridgeAdapter.sol';
import {IL1OpUSDCFactory, L1OpUSDCFactory} from 'contracts/L1OpUSDCFactory.sol';
import {L2OpUSDCFactory} from 'contracts/L2OpUSDCFactory.sol';
import {Test} from 'forge-std/Test.sol';
import {ICreate2Deployer} from 'interfaces/external/ICreate2Deployer.sol';
import {ICrossDomainMessenger} from 'interfaces/external/ICrossDomainMessenger.sol';
import {IUSDC} from 'interfaces/external/IUSDC.sol';
import {Helpers} from 'test/utils/Helpers.sol';

contract ForTestL1OpUSDCFactory is L1OpUSDCFactory {
  constructor(address _usdc, bytes32 _salt) L1OpUSDCFactory(_usdc, _salt) {}

  function forTest_setIsFactoryDeployed(address _l1Messenger, bool _deployed) public {
    isFactoryDeployed[_l1Messenger] = _deployed;
  }

  function forTest_getSalt() public view returns (bytes32 _salt) {
    _salt = _SALT;
  }

  function forTest_precalculateCreateAddress(
    address _deployer,
    uint256 _nonce
  ) public pure returns (address _precalculatedAddress) {
    _precalculatedAddress = _precalculateCreateAddress(_deployer, _nonce);
  }

  function forTest_precalculateCreate2Address(
    bytes32 _salt,
    bytes32 _initCodeHash,
    address _deployer
  ) public pure returns (address _precalculatedAddress) {
    _precalculatedAddress = _precalculateCreate2Address(_salt, _initCodeHash, _deployer);
  }
}

abstract contract Base is Test, Helpers {
  ForTestL1OpUSDCFactory public factory;

  bytes32 internal _salt = bytes32('32');
  address internal _owner = makeAddr('owner');
  address internal _user = makeAddr('user');
  address internal _usdc = makeAddr('USDC');
  bytes internal _usdcImplementationBytecode = '0x6080333333';
  address internal _usdcImplAddress = makeAddr('bridgedUsdcImpl');
  // cant fuzz this because of foundry's VM
  address internal _l1Messenger = makeAddr('messenger');

  bytes[] internal _usdcInitTxs;

  function setUp() public virtual {
    // Deploy factory
    factory = new ForTestL1OpUSDCFactory(_usdc, _salt);

    // Etch code for the usdc implementation so its retrieved when checking the bytecode
    vm.etch(_usdcImplAddress, _usdcImplementationBytecode);

    // Define the implementation structs info
    bytes memory _usdcInitTx = 'tx1';
    _usdcInitTxs.push(_usdcInitTx);
  }

  /**
   * @notice Helper function to mock all the function calls that will be made in the `deployAdapters` function,
   * and some that will be made in the `deployL2FactoryAndContracts` function
   */
  function _mockDeployFunctionCalls() internal {
    // Mock the call over the `portal` function on the L1 messenger
    vm.mockCall(_l1Messenger, abi.encodeWithSelector(ICrossDomainMessenger.sendMessage.selector), abi.encode(''));

    // Mock the call over the `implementation` function on the USDC contract
    vm.mockCall(_usdc, abi.encodeWithSelector(IUSDC.implementation.selector), abi.encode(_usdcImplAddress));
  }
}

contract L1OpUSDCFactory_Unit_Constructor is Base {
  /**
   * @notice Test the constructor params are correctly set
   */
  function test_setImmutables() public {
    // Get the init codes
    bytes memory _l2FactoryCreationCode = type(L2OpUSDCFactory).creationCode;
    bytes memory _l2FactoryCArgs = abi.encode(_salt, address(factory));
    bytes32 _l2FactoryInitCodeHash = keccak256(bytes.concat(_l2FactoryCreationCode, _l2FactoryCArgs));

    // Precalculate the addresses to be deployed using CREATE2
    address _l2Factory =
      factory.forTest_precalculateCreate2Address(_salt, _l2FactoryInitCodeHash, factory.L2_CREATE2_DEPLOYER());

    // Assert
    assertEq(factory.USDC(), _usdc, 'Invalid usdc address');
    assertEq(factory.forTest_getSalt(), _salt, 'Invalid salt value');
    assertEq(factory.L2_FACTORY(), _l2Factory, 'Invalid l2Factory address');
  }
}

contract L1OpUSDCFactory_Unit_DeployL2FactoryAndContracts is Base {
  /**
   * @notice Check the messenger is set as deployed on the `isMessengerDeployed` mapping
   */
  function test_setMessengerDeployed(uint32 _minGasLimitCreate2Factory, uint32 _minGasLimitDeploy) public {
    // Mock all the `deployL2FactoryAndContracts` function calls
    _mockDeployFunctionCalls();

    // Execute
    vm.prank(_user);
    factory.deployL2FactoryAndContracts(
      _l1Messenger, _owner, _minGasLimitCreate2Factory, _minGasLimitDeploy, _usdcInitTxs
    );

    // Assert
    assertTrue(factory.isFactoryDeployed(_l1Messenger), 'Messenger not deployed');
  }

  /**
   * @notice Check the `deploy` call over the `create2Deployer` is correctly sent through the messenger
   */
  function test_callSendMessage(uint32 _minGasLimitCreate2Factory, uint32 _minGasLimitDeploy) public {
    uint256 _zeroValue = 0;
    // Mock all the `deployL2FactoryAndContracts` function calls
    _mockDeployFunctionCalls();

    // Get the L2 factory deployment tx
    bytes memory _l2FactoryCreationCode = type(L2OpUSDCFactory).creationCode;
    bytes memory _l2FactoryCArgs = abi.encode(_salt, address(factory));
    bytes memory _l2FactoryInitCode = bytes.concat(_l2FactoryCreationCode, _l2FactoryCArgs);
    bytes memory _l2FactoryCreate2Tx =
      abi.encodeWithSelector(ICreate2Deployer.deploy.selector, _zeroValue, _salt, _l2FactoryInitCode);

    // Expect the `sendMessage` to be properly called
    vm.expectCall(
      _l1Messenger,
      abi.encodeWithSelector(
        ICrossDomainMessenger.sendMessage.selector,
        factory.L2_CREATE2_DEPLOYER(),
        _l2FactoryCreate2Tx,
        _minGasLimitCreate2Factory
      )
    );

    // Execute
    vm.prank(_user);
    factory.deployL2FactoryAndContracts(
      _l1Messenger, _owner, _minGasLimitCreate2Factory, _minGasLimitDeploy, _usdcInitTxs
    );
  }

  /**
   * @notice Check the `deployAdapters` function is called on the `deployAdapters` function by checking
   * that the message to deploy those L2 contracts is properly sent
   */
  function test_callDeployAdapters(uint32 _minGasLimitCreate2Factory, uint32 _minGasLimitDeploy) public {
    // Get the l1 adapter address
    uint256 _factoryNonce = vm.getNonce(address(factory));
    address _l1Adapter = factory.forTest_precalculateCreateAddress(address(factory), _factoryNonce);

    // Mock all the `deployL2FactoryAndContracts` function calls
    _mockDeployFunctionCalls();

    // Expect the `sendMessage` to be properly called
    bytes memory _l2DeploymentsTx =
      abi.encodeWithSelector(L2OpUSDCFactory.deploy.selector, _l1Adapter, _usdcImplementationBytecode, _usdcInitTxs);
    vm.expectCall(
      _l1Messenger,
      abi.encodeWithSelector(
        ICrossDomainMessenger.sendMessage.selector, factory.L2_FACTORY(), _l2DeploymentsTx, _minGasLimitDeploy
      )
    );

    // Execute
    vm.prank(_user);
    factory.deployL2FactoryAndContracts(
      _l1Messenger, _owner, _minGasLimitCreate2Factory, _minGasLimitDeploy, _usdcInitTxs
    );
  }
}

contract L1OpUSDCFactory_Unit_DeployAdapters is Base {
  event L1AdapterDeployed(address _l1Adapter);

  function setUp() public override {
    super.setUp();
    // Set the L2 factory as deployed for the L1 messenger
    factory.forTest_setIsFactoryDeployed(_l1Messenger, true);
  }

  function test_revertIfFactoryNotDeployed(uint32 _minGasLimitDeploy) public {
    // Mock the `isMessengerDeployed` to return true
    factory.forTest_setIsFactoryDeployed(_l1Messenger, false);

    // Execute
    vm.prank(_user);
    vm.expectRevert(IL1OpUSDCFactory.IL1OpUSDCFactory_FactoryNotDeployed.selector);
    factory.deployAdapters(_l1Messenger, _owner, _minGasLimitDeploy, _usdcInitTxs);
  }

  function test_updateNonce(uint32 _minGasLimitDeploy) public {
    uint256 _nonceBefore = factory.nonce();

    // Mock all the `deployAdapters` function calls
    _mockDeployFunctionCalls();

    // Execute
    vm.prank(_user);
    factory.deployAdapters(_l1Messenger, _owner, _minGasLimitDeploy, _usdcInitTxs);

    // Assert
    uint256 _numberOfDeployments = 1;
    assertEq(factory.nonce(), _nonceBefore + _numberOfDeployments, 'Invalid nonce');
  }

  /**
   * @notice Check the function deploys the L1 adapter correctly and sends the message to the L2 factory to execute the
   * L2 deployments
   * @dev Assuming the `L1OpUSDCBridgeAdapter` sets the immutables correctly to check we are passing the right values
   */
  function test_deployL1Adapter(uint32 _minGasLimitDeploy) public {
    uint256 _factoryNonce = vm.getNonce(address(factory));
    address _l1Adapter = factory.forTest_precalculateCreateAddress(address(factory), _factoryNonce);

    address _l2Adapter = factory.forTest_precalculateCreateAddress(factory.L2_FACTORY(), _factoryNonce + 1);

    // Mock all the `deployAdapters` function calls
    _mockDeployFunctionCalls();

    // Execute
    vm.prank(_user);
    factory.deployAdapters(_l1Messenger, _owner, _minGasLimitDeploy, _usdcInitTxs);

    // Assert the contract was deployed by checking its bytecode length is greater than 0
    assertGt(_l1Adapter.code.length, 0, 'L1 adapter not deployed');
    // Check the constructor values were properly passed
    assertEq(L1OpUSDCBridgeAdapter(_l1Adapter).USDC(), _usdc, 'Invalid USDC address');
    assertEq(L1OpUSDCBridgeAdapter(_l1Adapter).MESSENGER(), _l1Messenger, 'Invalid messenger address');
    assertEq(L1OpUSDCBridgeAdapter(_l1Adapter).LINKED_ADAPTER(), _l2Adapter, 'Invalid linked adapter address');
    assertEq(L1OpUSDCBridgeAdapter(_l1Adapter).owner(), _owner, 'Invalid owner address');
  }

  function test_callUSDCImplementation(uint32 _minGasLimitDeploy) public {
    // Mock all the `deployAdapters` function calls
    _mockDeployFunctionCalls();

    // Expect the `bridgedUSDCImplementation` to be properly called
    vm.expectCall(_usdc, abi.encodeWithSelector(IUSDC.implementation.selector));

    // Execute
    vm.prank(_user);
    factory.deployAdapters(_l1Messenger, _owner, _minGasLimitDeploy, _usdcInitTxs);
  }

  /**
   * @notice Check the `_deployAdapters` function calls the `sendMessage` correctly. We use a for test function
   * to get the internal because the `sendMessage` function is not public
   */
  function test_callSendMessage(uint32 _minGasLimitDeploy) public {
    // Calculate the l1 adapter address
    uint256 _factoryNonce = vm.getNonce(address(factory));
    address _l1Adapter = factory.forTest_precalculateCreateAddress(address(factory), _factoryNonce);

    // Mock all the `deployL2FactoryAndContracts` function calls
    _mockDeployFunctionCalls();

    // Expect the `sendMessage` to be properly called
    bytes memory _l2DeploymentsTx =
      abi.encodeWithSelector(L2OpUSDCFactory.deploy.selector, _l1Adapter, _usdcImplementationBytecode, _usdcInitTxs);
    vm.expectCall(
      _l1Messenger,
      abi.encodeWithSelector(
        ICrossDomainMessenger.sendMessage.selector, factory.L2_FACTORY(), _l2DeploymentsTx, _minGasLimitDeploy
      )
    );

    // Execute
    vm.prank(_user);
    factory.deployAdapters(_l1Messenger, _owner, _minGasLimitDeploy, _usdcInitTxs);
  }

  function test_emitEvent(uint32 _minGasLimitDeploy) public {
    // Calculate the l1 adapter address
    uint256 _factoryNonce = vm.getNonce(address(factory));
    address _l1Adapter = factory.forTest_precalculateCreateAddress(address(factory), _factoryNonce);

    // Mock all the `deployAdapters` function calls
    _mockDeployFunctionCalls();

    // Expect the `L1AdapterDeployed` event to be emitted
    vm.expectEmit(true, true, true, true);
    emit L1AdapterDeployed(_l1Adapter);

    // Execute
    vm.prank(_user);
    factory.deployAdapters(_l1Messenger, _owner, _minGasLimitDeploy, _usdcInitTxs);
  }
}

contract L1OpUSDCFactory_Unit_PrecalculateCreateAddress is Base {
  function test_revertOnInvalidNonce(address _deployer) public {
    uint64 _maxNonce = 2 ** 64 - 2;
    uint64 _nonce = _maxNonce + 1;
    // Setting a higher nonce than the deployer's current one will revert
    vm.setNonce(_user, _nonce);

    // Expect the call to revert
    vm.expectRevert(IL1OpUSDCFactory.IL1OpUSDCFactory_InvalidNonce.selector);

    // Execute
    factory.forTest_precalculateCreateAddress(_deployer, _nonce);
  }

  /**
   * @notice Check the `precalculateCreateAddress` function returns the correct address for the given deployer and nonce
   * We are testing the range from 1 to 127 since the function only covers that range which is enough for the factory
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
  error Create2Failed();

  /**
   * @notice Check the `precalculateCreate2Address` function returns the correct address for the given salt, init code
   *  hash, and deployer
   */
  function test_precalculateCreate2Address(bytes32 _salt, address _deployer) public {
    // Get the dumy contract init code and its hash
    bytes memory _initCode = type(ForTest_DummyContract).creationCode;
    bytes32 _initCodeHash = keccak256(_initCode);

    // Precalculate the address
    address _precalculatedAddress = factory.forTest_precalculateCreate2Address(_salt, _initCodeHash, _deployer);
    address _newAddress;

    // Execute
    vm.prank(_deployer);
    assembly ("memory-safe") {
      _newAddress := create2(callvalue(), add(_initCode, 0x20), mload(_initCode), _salt)
    }
    if (_newAddress == address(0) || _newAddress.code.length == 0) {
      revert Create2Failed();
    }

    // Assert
    assertEq(_newAddress, _precalculatedAddress, 'Invalid create2 precalculated address');
  }
}

/**
 * @notice Dummy contract to be deployed only for testing purposes
 */
contract ForTest_DummyContract {}
