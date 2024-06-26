// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {L1OpUSDCBridgeAdapter} from 'contracts/L1OpUSDCBridgeAdapter.sol';
import {IL1OpUSDCFactory, L1OpUSDCFactory} from 'contracts/L1OpUSDCFactory.sol';
import {L2OpUSDCBridgeAdapter} from 'contracts/L2OpUSDCBridgeAdapter.sol';
import {L2OpUSDCFactory} from 'contracts/L2OpUSDCFactory.sol';
import {USDCInitTxs} from 'contracts/utils/USDCInitTxs.sol';

import {StdStorage, stdStorage} from 'forge-std/StdStorage.sol';
import {IL2OpUSDCFactory} from 'interfaces/IL2OpUSDCFactory.sol';
import {IUSDC} from 'interfaces/external/IUSDC.sol';

import {USDC_IMPLEMENTATION_CREATION_CODE} from 'script/utils/USDCImplementationCreationCode.sol';
import {AddressAliasHelper} from 'test/utils/AddressAliasHelper.sol';
import {Helpers} from 'test/utils/Helpers.sol';
import {ITestCrossDomainMessenger} from 'test/utils/interfaces/ITestCrossDomainMessenger.sol';

contract IntegrationBase is Helpers {
  using stdStorage for StdStorage;

  // Constants
  uint256 internal constant _SEPOLIA_FORK_BLOCK = 6_192_669;
  uint256 internal constant _OP_SEPOLIA_FORK_BLOCK = 13_813_086;
  // uint256 internal constant _BASE_FORK_BLOCK = 16_281_004;

  IUSDC public constant MAINNET_USDC = IUSDC(0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238);
  address public constant MAINNET_USDC_IMPLEMENTATION = 0x43506849D7C04F9138D1A2050bbF3A0c054402dd;
  address public constant L2_CREATE2_DEPLOYER = 0x13b0D85CcB8bf860b6b79AF3029fCA081AE9beF2;
  address public constant OPTIMISM_PORTAL = 0x16Fc5058F25648194471939df75CF27A2fdC48BC;
  ITestCrossDomainMessenger public constant L2_MESSENGER =
    ITestCrossDomainMessenger(0x4200000000000000000000000000000000000007);
  ITestCrossDomainMessenger public constant OPTIMISM_L1_MESSENGER =
    ITestCrossDomainMessenger(0x58Cc85b8D04EA49cC6DBd3CbFFd00B4B8D6cb3ef);
  ITestCrossDomainMessenger public constant BASE_L1_MESSENGER =
    ITestCrossDomainMessenger(0xC34855F4De64F1840e5686e64278da901e261f20);
  uint32 public constant MIN_GAS_LIMIT_DEPLOY = 8_000_000;
  uint32 internal constant _ZERO_VALUE = 0;
  uint256 internal constant _amount = 1e18;
  uint32 internal constant _MIN_GAS_LIMIT = 7_000_000;

  /// @notice Value used for the L2 sender storage slot in both the OptimismPortal and the
  ///         CrossDomainMessenger contracts before an actual sender is set. This value is
  ///         non-zero to reduce the gas cost of message passing transactions.
  address internal constant _DEFAULT_L2_SENDER = 0x000000000000000000000000000000000000dEaD;

  // solhint-disable-next-line max-line-length
  address public immutable OP_ALIASED_L1_MESSENGER = AddressAliasHelper.applyL1ToL2Alias(address(OPTIMISM_L1_MESSENGER));
  address public immutable BASE_ALIASED_L1_MESSENGER = AddressAliasHelper.applyL1ToL2Alias(address(BASE_L1_MESSENGER));

  // Fork variables
  uint256 public mainnet;
  uint256 public optimism;
  // uint256 public base;

  // EOA addresses
  address internal _owner = makeAddr('owner');
  address internal _user = makeAddr('user');

  // Helper variables
  bytes[] public usdcInitTxns = new bytes[](3);
  bytes public initialize;

  // OpUSDC Protocol
  L1OpUSDCBridgeAdapter public l1Adapter;
  L1OpUSDCFactory public l1Factory;
  L2OpUSDCFactory public l2Factory;
  L2OpUSDCBridgeAdapter public l2Adapter;
  IUSDC public bridgedUSDC;
  IL2OpUSDCFactory.USDCInitializeData public usdcInitializeData;
  IL1OpUSDCFactory.L2Deployments public l2Deployments;

  function setUp() public virtual {
    mainnet = vm.createFork(vm.rpcUrl('sepolia'), _SEPOLIA_FORK_BLOCK);
    optimism = vm.createFork(vm.rpcUrl('op-sepolia'), _OP_SEPOLIA_FORK_BLOCK);
    // base = vm.createFork(vm.rpcUrl('base'), _BASE_FORK_BLOCK);

    l1Factory = new L1OpUSDCFactory(address(MAINNET_USDC));

    // Define the initialization transactions
    usdcInitTxns[0] = USDCInitTxs.INITIALIZEV2;
    usdcInitTxns[1] = USDCInitTxs.INITIALIZEV2_1;
    usdcInitTxns[2] = USDCInitTxs.INITIALIZEV2_2;
    // Define the L2 deployments data
    l2Deployments =
      IL1OpUSDCFactory.L2Deployments(_owner, USDC_IMPLEMENTATION_CREATION_CODE, usdcInitTxns, MIN_GAS_LIMIT_DEPLOY);

    vm.selectFork(mainnet);

    vm.prank(_owner);
    (address _l1Adapter, address _l2Factory, address _l2Adapter) =
      l1Factory.deploy(address(OPTIMISM_L1_MESSENGER), _owner, l2Deployments);

    l1Adapter = L1OpUSDCBridgeAdapter(_l1Adapter);

    // Get salt and initialize data for l2 deployments
    bytes32 _salt = bytes32(l1Factory.deploymentsSaltCounter());
    usdcInitializeData = IL2OpUSDCFactory.USDCInitializeData(
      l1Factory.USDC_NAME(), l1Factory.USDC_SYMBOL(), MAINNET_USDC.currency(), MAINNET_USDC.decimals()
    );

    // Give max minting power to the master minter
    address _masterMinter = MAINNET_USDC.masterMinter();
    vm.prank(_masterMinter);
    MAINNET_USDC.configureMinter(_masterMinter, type(uint256).max);

    vm.selectFork(optimism);
    _relayL2Deployments(OP_ALIASED_L1_MESSENGER, _salt, _l1Adapter, usdcInitializeData, l2Deployments);

    l2Adapter = L2OpUSDCBridgeAdapter(_l2Adapter);
    bridgedUSDC = IUSDC(l2Adapter.USDC());
    l2Factory = L2OpUSDCFactory(_l2Factory);

    // Make foundry know these two address exist on both forks
    vm.makePersistent(address(l1Adapter));
    vm.makePersistent(address(l2Adapter));
    vm.makePersistent(address(bridgedUSDC));
    vm.makePersistent(address(l2Adapter.FALLBACK_PROXY_ADMIN()));
    vm.makePersistent(address(l2Factory));
  }

  function _relayL2Deployments(
    address _aliasedL1Messenger,
    bytes32 _salt,
    address _l1Adapter,
    IL2OpUSDCFactory.USDCInitializeData memory _usdcInitializeData,
    IL1OpUSDCFactory.L2Deployments memory _l2Deployments
  ) internal {
    bytes memory _l2FactoryCArgs = abi.encode(
      _l1Adapter,
      _l2Deployments.l2AdapterOwner,
      _l2Deployments.usdcImplementationInitCode,
      _usdcInitializeData,
      _l2Deployments.usdcInitTxs
    );
    bytes memory _l2FactoryInitCode = bytes.concat(type(L2OpUSDCFactory).creationCode, _l2FactoryCArgs);

    _relayL1ToL2Message(
      _aliasedL1Messenger,
      address(l1Factory),
      L2_CREATE2_DEPLOYER,
      _ZERO_VALUE,
      _l2Deployments.minGasLimitDeploy,
      abi.encodeWithSignature('deploy(uint256,bytes32,bytes)', _ZERO_VALUE, _salt, _l2FactoryInitCode)
    );
  }

  function _mintSupplyOnL2(uint256 _network, address _aliasedL1Messenger, uint256 _supply) internal {
    vm.selectFork(mainnet);

    // We need to do this instead of `deal` because deal doesnt change `totalSupply` state
    vm.startPrank(MAINNET_USDC.masterMinter());
    MAINNET_USDC.configureMinter(MAINNET_USDC.masterMinter(), _supply);
    MAINNET_USDC.mint(_user, _supply);
    vm.stopPrank();

    vm.startPrank(_user);
    MAINNET_USDC.approve(address(l1Adapter), _supply);
    l1Adapter.sendMessage(_user, _supply, _MIN_GAS_LIMIT);
    vm.stopPrank();

    vm.selectFork(_network);
    _relayL1ToL2Message(
      _aliasedL1Messenger,
      address(l1Adapter),
      address(l2Adapter),
      0,
      _MIN_GAS_LIMIT,
      abi.encodeWithSignature('receiveMessage(address,uint256)', _user, _supply)
    );
  }

  function _relayL1ToL2Message(
    address _aliasedL1Messenger,
    address _sender,
    address _target,
    uint256 _value,
    uint256 _minGasLimit,
    bytes memory _data
  ) internal {
    uint256 _messageNonce = L2_MESSENGER.messageNonce();
    vm.startPrank(_aliasedL1Messenger);

    L2_MESSENGER.relayMessage{gas: _minGasLimit}(_messageNonce + 1, _sender, _target, _value, _minGasLimit, _data);
    vm.stopPrank();
  }

  function _relayL2ToL1Message(
    address _sender,
    address _target,
    uint256 _value,
    uint256 _minGasLimit,
    bytes memory _data
  ) internal {
    uint256 _messageNonce = OPTIMISM_L1_MESSENGER.messageNonce();

    // For simplicity we do this as this slot is not exposed until prove and finalize is done
    stdstore.target(OPTIMISM_PORTAL).sig('l2Sender()').checked_write(address(L2_MESSENGER));
    vm.startPrank(OPTIMISM_PORTAL);
    OPTIMISM_L1_MESSENGER.relayMessage(_messageNonce + 1, _sender, _target, _value, _minGasLimit, _data);
    vm.stopPrank();
    // Needs to be reset to mimic production
    stdstore.target(OPTIMISM_PORTAL).sig('l2Sender()').checked_write(_DEFAULT_L2_SENDER);
  }
}

contract IntegrationSetup is IntegrationBase {
  function testSetup() public {
    vm.selectFork(mainnet);
    assertEq(l1Adapter.LINKED_ADAPTER(), address(l2Adapter));

    vm.selectFork(optimism);
    assertEq(l2Adapter.LINKED_ADAPTER(), address(l1Adapter));
    assertEq(l2Adapter.FALLBACK_PROXY_ADMIN().owner(), address(l2Adapter));
  }
}
