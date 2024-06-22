// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {L1OpUSDCBridgeAdapter} from 'contracts/L1OpUSDCBridgeAdapter.sol';
import {IL1OpUSDCFactory, L1OpUSDCFactory} from 'contracts/L1OpUSDCFactory.sol';
import {L2OpUSDCBridgeAdapter} from 'contracts/L2OpUSDCBridgeAdapter.sol';
import {L2OpUSDCFactory} from 'contracts/L2OpUSDCFactory.sol';
import {USDCInitTxs} from 'contracts/utils/USDCInitTxs.sol';
import {IL2OpUSDCFactory} from 'interfaces/IL2OpUSDCFactory.sol';
import {IUSDC} from 'interfaces/external/IUSDC.sol';
import {AddressAliasHelper} from 'test/utils/AddressAliasHelper.sol';
import {Helpers} from 'test/utils/Helpers.sol';
import {USDC_IMPLEMENTATION_CREATION_CODE} from 'test/utils/USDCImplementationCreationCode.sol';
import {IMockCrossDomainMessenger} from 'test/utils/interfaces/IMockCrossDomainMessenger.sol';

contract IntegrationBase is Helpers {
  // Constants
  uint256 internal constant _MAINNET_FORK_BLOCK = 20_076_176;
  uint256 internal constant _OPTIMISM_FORK_BLOCK = 121_300_856;
  IUSDC public constant MAINNET_USDC = IUSDC(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
  address public constant MAINNET_USDC_IMPLEMENTATION = 0x43506849D7C04F9138D1A2050bbF3A0c054402dd;
  address public constant L2_CREATE2_DEPLOYER = 0x13b0D85CcB8bf860b6b79AF3029fCA081AE9beF2;
  address public constant OPTIMISM_PORTAL = 0xbEb5Fc579115071764c7423A4f12eDde41f106Ed;
  IMockCrossDomainMessenger public constant L2_MESSENGER =
    IMockCrossDomainMessenger(0x4200000000000000000000000000000000000007);
  IMockCrossDomainMessenger public constant OPTIMISM_L1_MESSENGER =
    IMockCrossDomainMessenger(0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1);
  uint32 public constant MIN_GAS_LIMIT_DEPLOY = 8_000_000;
  uint32 internal constant _ZERO_VALUE = 0;
  uint256 internal constant _amount = 1e18;
  uint32 internal constant _minGasLimit = 1_000_000;

  /// @notice Value used for the L2 sender storage slot in both the OptimismPortal and the
  ///         CrossDomainMessenger contracts before an actual sender is set. This value is
  ///         non-zero to reduce the gas cost of message passing transactions.
  address internal constant _DEFAULT_L2_SENDER = 0x000000000000000000000000000000000000dEaD;

  address public immutable ALIASED_L1_MESSENGER = AddressAliasHelper.applyL1ToL2Alias(address(OPTIMISM_L1_MESSENGER));

  // Fork variables
  uint256 public optimism;
  uint256 public mainnet;

  // EOA addresses
  address internal _owner = makeAddr('owner');
  address internal _user = makeAddr('user');

  // Helper variables
  bytes[] public usdcInitTxns = new bytes[](3);
  bytes public initialize;

  // OpUSDC Protocol
  L1OpUSDCBridgeAdapter public l1Adapter;
  L1OpUSDCFactory public factory;
  L2OpUSDCBridgeAdapter public l2Adapter;
  IUSDC public bridgedUSDC;
  IL2OpUSDCFactory.USDCInitializeData public usdcInitializeData;
  IL1OpUSDCFactory.L2Deployments public l2Deployments;

  function setUp() public virtual {
    mainnet = vm.createFork(vm.rpcUrl('mainnet'), _MAINNET_FORK_BLOCK);
    optimism = vm.createFork(vm.rpcUrl('optimism'), _OPTIMISM_FORK_BLOCK);

    factory = new L1OpUSDCFactory(address(MAINNET_USDC));

    // Define the initialization transactions
    usdcInitTxns[0] = USDCInitTxs.INITIALIZEV2;
    usdcInitTxns[1] = USDCInitTxs.INITIALIZEV2_1;
    usdcInitTxns[2] = USDCInitTxs.INITIALIZEV2_2;
    // Define the L2 deployments data
    l2Deployments =
      IL1OpUSDCFactory.L2Deployments(_owner, USDC_IMPLEMENTATION_CREATION_CODE, usdcInitTxns, MIN_GAS_LIMIT_DEPLOY);

    vm.selectFork(mainnet);

    vm.prank(_owner);
    (address _l1Adapter,, address _l2Adapter) = factory.deploy(address(OPTIMISM_L1_MESSENGER), _owner, l2Deployments);

    l1Adapter = L1OpUSDCBridgeAdapter(_l1Adapter);

    // Get salt and initialize data for l2 deployments
    bytes32 _salt = bytes32(factory.deploymentsSaltCounter());
    usdcInitializeData = IL2OpUSDCFactory.USDCInitializeData(
      factory.USDC_NAME(), factory.USDC_SYMBOL(), MAINNET_USDC.currency(), MAINNET_USDC.decimals()
    );

    // Give max minting power to the master minter
    address _masterMinter = MAINNET_USDC.masterMinter();
    vm.prank(_masterMinter);
    MAINNET_USDC.configureMinter(_masterMinter, type(uint256).max);

    vm.selectFork(optimism);
    _relayL2Deployments(_salt, _l1Adapter, usdcInitializeData, l2Deployments);

    l2Adapter = L2OpUSDCBridgeAdapter(_l2Adapter);
    bridgedUSDC = IUSDC(l2Adapter.USDC());

    // Make foundry know these two address exist on both forks
    vm.makePersistent(address(_l1Adapter));
    vm.makePersistent(address(l2Adapter));
    vm.makePersistent(address(bridgedUSDC));
    vm.makePersistent(address(l2Adapter.FALLBACK_PROXY_ADMIN()));
  }

  function _relayL2Deployments(
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
    uint256 _messageNonce = L2_MESSENGER.messageNonce();

    vm.prank(ALIASED_L1_MESSENGER);
    L2_MESSENGER.relayMessage(
      _messageNonce + 1,
      address(factory),
      L2_CREATE2_DEPLOYER,
      _ZERO_VALUE,
      _l2Deployments.minGasLimitDeploy,
      abi.encodeWithSignature('deploy(uint256,bytes32,bytes)', _ZERO_VALUE, _salt, _l2FactoryInitCode)
    );
  }

  function _mintSupplyOnL2(uint256 _supply) internal {
    vm.selectFork(mainnet);

    // We need to do this instead of `deal` because deal doesnt change `totalSupply` state
    vm.startPrank(MAINNET_USDC.masterMinter());
    MAINNET_USDC.configureMinter(MAINNET_USDC.masterMinter(), _supply);
    MAINNET_USDC.mint(_user, _supply);
    vm.stopPrank();

    vm.startPrank(_user);
    MAINNET_USDC.approve(address(l1Adapter), _supply);
    l1Adapter.sendMessage(_user, _supply, _minGasLimit);
    vm.stopPrank();

    vm.selectFork(optimism);
    uint256 _messageNonce = L2_MESSENGER.messageNonce();

    vm.prank(ALIASED_L1_MESSENGER);
    L2_MESSENGER.relayMessage(
      _messageNonce + 1,
      address(l1Adapter),
      address(l2Adapter),
      0,
      1_000_000,
      abi.encodeWithSignature('receiveMessage(address,uint256)', _user, _supply)
    );
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
