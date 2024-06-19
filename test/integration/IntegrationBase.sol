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
  bytes32 public constant SALT = keccak256(abi.encode('32'));
  string public constant TOKEN_NAME = 'USD Coin';
  string public constant TOKEN_SYMBOL = 'USDC';
  uint32 public constant MIN_GAS_LIMIT_FACTORY = 4_000_000;
  uint32 public constant MIN_GAS_LIMIT_DEPLOY = 8_000_000;
  uint32 internal constant _ZERO_VALUE = 0;

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

  function setUp() public virtual {
    mainnet = vm.createFork(vm.rpcUrl('mainnet'), _MAINNET_FORK_BLOCK);
    optimism = vm.createFork(vm.rpcUrl('optimism'), _OPTIMISM_FORK_BLOCK);

    factory = new L1OpUSDCFactory(address(MAINNET_USDC));

    // Define the initialization transactions
    usdcInitTxns[0] = USDCInitTxs.INITIALIZEV2;
    usdcInitTxns[1] = USDCInitTxs.INITIALIZEV2_1;
    usdcInitTxns[2] = USDCInitTxs.INITIALIZEV2_2;
    // Define the L2 deployments data
    IL1OpUSDCFactory.L2Deployments memory _l2Deployments = IL1OpUSDCFactory.L2Deployments(
      _owner, USDC_IMPLEMENTATION_CREATION_CODE, usdcInitTxns, MIN_GAS_LIMIT_FACTORY, MIN_GAS_LIMIT_DEPLOY
    );

    vm.selectFork(mainnet);

    vm.startPrank(_owner);
    (address _l1Adapter, address _l2Factory, address _l2Adapter) =
      factory.deploy(address(OPTIMISM_L1_MESSENGER), _owner, _l2Deployments);
    vm.stopPrank();
    bytes32 _salt = bytes32(factory.deploymentsSaltCounter());

    l1Adapter = L1OpUSDCBridgeAdapter(_l1Adapter);

    usdcInitializeData =
      IL2OpUSDCFactory.USDCInitializeData(TOKEN_NAME, TOKEN_SYMBOL, MAINNET_USDC.currency(), MAINNET_USDC.decimals());
    vm.selectFork(optimism);
    _relayL2Deployments(_salt, _l1Adapter, _l2Factory, usdcInitializeData, _l2Deployments);

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
    address _l2Factory,
    IL2OpUSDCFactory.USDCInitializeData memory _usdcInitializeData,
    IL1OpUSDCFactory.L2Deployments memory _l2Deployments
  ) internal {
    bytes memory _l2FactoryCreationCode = type(L2OpUSDCFactory).creationCode;
    bytes memory _l2FactoryCArgs = abi.encode(address(factory));
    bytes memory _l2FactoryInitCode = bytes.concat(_l2FactoryCreationCode, _l2FactoryCArgs);

    vm.startPrank(AddressAliasHelper.applyL1ToL2Alias(address(OPTIMISM_L1_MESSENGER)));

    L2_MESSENGER.relayMessage(
      L2_MESSENGER.messageNonce() + 1,
      address(factory),
      address(L2_CREATE2_DEPLOYER),
      _ZERO_VALUE,
      MIN_GAS_LIMIT_FACTORY,
      abi.encodeWithSignature('deploy(uint256,bytes32,bytes)', _ZERO_VALUE, _salt, _l2FactoryInitCode)
    );

    L2_MESSENGER.relayMessage(
      L2_MESSENGER.messageNonce() + 2,
      address(factory),
      address(_l2Factory),
      _ZERO_VALUE,
      MIN_GAS_LIMIT_DEPLOY,
      abi.encodeWithSelector(
        L2OpUSDCFactory.deploy.selector,
        _l1Adapter,
        _l2Deployments.l2AdapterOwner,
        _l2Deployments.usdcImplementationInitCode,
        _usdcInitializeData,
        _l2Deployments.usdcInitTxs
      )
    );

    vm.stopPrank();
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
