// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {L1OpUSDCBridgeAdapter} from 'contracts/L1OpUSDCBridgeAdapter.sol';
import {IL1OpUSDCFactory, L1OpUSDCFactory} from 'contracts/L1OpUSDCFactory.sol';
import {L2OpUSDCBridgeAdapter} from 'contracts/L2OpUSDCBridgeAdapter.sol';
import {L2OpUSDCDeploy} from 'contracts/L2OpUSDCDeploy.sol';
import {USDCInitTxs} from 'contracts/utils/USDCInitTxs.sol';
import {StdStorage, stdStorage} from 'forge-std/StdStorage.sol';
import {IL2OpUSDCDeploy} from 'interfaces/IL2OpUSDCDeploy.sol';
import {IUSDC} from 'interfaces/external/IUSDC.sol';
import {AddressAliasHelper} from 'test/utils/AddressAliasHelper.sol';
import {Helpers} from 'test/utils/Helpers.sol';
import {USDC_IMPLEMENTATION_CREATION_CODE} from 'test/utils/USDCImplementationCreationCode.sol';
import {ITestCrossDomainMessenger} from 'test/utils/interfaces/ITestCrossDomainMessenger.sol';

contract IntegrationBase is Helpers {
  using stdStorage for StdStorage;

  // Constants
  uint256 internal constant _MAINNET_FORK_BLOCK = 20_171_419;
  uint256 internal constant _OPTIMISM_FORK_BLOCK = 121_876_282;
  uint256 internal constant _BASE_FORK_BLOCK = 16_281_004;

  IUSDC public constant MAINNET_USDC = IUSDC(0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238);
  address public constant MAINNET_USDC_IMPLEMENTATION = 0x43506849D7C04F9138D1A2050bbF3A0c054402dd;
  address public constant L2_CREATE2_DEPLOYER = 0x13b0D85CcB8bf860b6b79AF3029fCA081AE9beF2;
  address public constant OPTIMISM_PORTAL = 0x16Fc5058F25648194471939df75CF27A2fdC48BC;
  ITestCrossDomainMessenger public constant L2_MESSENGER =
    ITestCrossDomainMessenger(0x4200000000000000000000000000000000000007);
  ITestCrossDomainMessenger public constant OPTIMISM_L1_MESSENGER =
    ITestCrossDomainMessenger(0x58Cc85b8D04EA49cC6DBd3CbFFd00B4B8D6cb3ef);
  ITestCrossDomainMessenger public constant BASE_L1_MESSENGER =
    ITestCrossDomainMessenger(0x866E82a600A1414e583f7F13623F1aC5d58b0Afa);
  uint32 public constant MIN_GAS_LIMIT_DEPLOY = 9_000_000;
  uint32 internal constant _ZERO_VALUE = 0;
  uint256 internal constant _amount = 1e18;
  uint32 internal constant _MIN_GAS_LIMIT = 1_000_000;
  // The extra gas buffer added to the minimum gas limit for the relayMessage function
  uint64 internal constant _SEQUENCER_GAS_OVERHEAD = 700_000;
  uint256 internal constant _USER_NONCE = 1;
  string public constant CHAIN_NAME = 'Test';

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
  uint256 public base;

  // EOA addresses
  address internal _owner = 0x8421D6D2253d3f8e25586Aa6692b1Bf591da3779; // makeAddr('owner');
  address internal _user = makeAddr('user');

  // Helper variables
  bytes[] public usdcInitTxns = new bytes[](3);
  bytes public initialize;

  // OpUSDC Protocol
  L1OpUSDCBridgeAdapter public l1Adapter;
  L1OpUSDCFactory public l1Factory;
  L2OpUSDCDeploy public l2Factory;
  L2OpUSDCBridgeAdapter public l2Adapter;
  IUSDC public bridgedUSDC;
  IL2OpUSDCDeploy.USDCInitializeData public usdcInitializeData;
  IL1OpUSDCFactory.L2Deployments public l2Deployments;

  function setUp() public virtual {
    mainnet =
      vm.createFork(vm.rpcUrl('https://eth-sepolia.g.alchemy.com/v2/IRdWoKj7-6dnihhXL33ILI6AgyYKt1eY'), 6_814_077);
    optimism =
      vm.createFork(vm.rpcUrl('https://opt-sepolia.g.alchemy.com/v2/IRdWoKj7-6dnihhXL33ILI6AgyYKt1eY'), 18_126_898);
    // base = vm.createFork(vm.rpcUrl('base'), _BASE_FORK_BLOCK);

    // l1Factory = new L1OpUSDCFactory(address(MAINNET_USDC));

    // vm.selectFork(optimism);
    // address _usdcImplAddr;
    // bytes memory _USDC_IMPLEMENTATION_CREATION_CODE = USDC_IMPLEMENTATION_CREATION_CODE;
    // assembly {
    //   _usdcImplAddr :=
    //     create(0, add(_USDC_IMPLEMENTATION_CREATION_CODE, 0x20), mload(_USDC_IMPLEMENTATION_CREATION_CODE))
    // }

    vm.selectFork(mainnet);

    l1Adapter = L1OpUSDCBridgeAdapter(0x0429b5441c85EF7932B694f1998B778D89375b12);
    // Give max minting power to the master minter
    address _masterMinter = MAINNET_USDC.masterMinter();
    vm.prank(_masterMinter);
    MAINNET_USDC.configureMinter(_masterMinter, type(uint256).max);

    vm.selectFork(optimism);
    l2Adapter = L2OpUSDCBridgeAdapter(0xCe7bb486F2b17735a2ee7566Fe03cA77b1a1aa9d);

    bridgedUSDC = IUSDC(l2Adapter.USDC());

    // Make foundry know these two address exist on both forks
    vm.makePersistent(address(l1Adapter));
    vm.makePersistent(address(l2Adapter));
    vm.makePersistent(address(bridgedUSDC));
    vm.makePersistent(address(l2Adapter.FALLBACK_PROXY_ADMIN()));
    // vm.makePersistent(address(l2Factory));
  }

  function _relayL2Deployments(
    address _aliasedL1Messenger,
    bytes32 _salt,
    address _l1Adapter,
    IL2OpUSDCDeploy.USDCInitializeData memory _usdcInitializeData,
    IL1OpUSDCFactory.L2Deployments memory _l2Deployments
  ) internal {
    bytes memory _l2FactoryCArgs = abi.encode(
      _l1Adapter,
      _l2Deployments.l2AdapterOwner,
      _l2Deployments.usdcImplAddr,
      _usdcInitializeData,
      _l2Deployments.usdcInitTxs
    );
    bytes memory _l2FactoryInitCode = bytes.concat(type(L2OpUSDCDeploy).creationCode, _l2FactoryCArgs);

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
    uint64 _minGasLimitMint = 1_000_000;
    _relayL1ToL2Message(
      _aliasedL1Messenger,
      address(l1Adapter),
      address(l2Adapter),
      _ZERO_VALUE,
      _minGasLimitMint,
      abi.encodeWithSignature('receiveMessage(address,address,uint256)', _user, _user, _supply)
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
    vm.prank(_aliasedL1Messenger);
    // OP adds some extra gas for the relayMessage logic
    L2_MESSENGER.relayMessage{gas: _minGasLimit + _SEQUENCER_GAS_OVERHEAD}(
      _messageNonce, _sender, _target, _value, _minGasLimit, _data
    );
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
    vm.prank(OPTIMISM_PORTAL);
    // OP adds some extra gas for the relayMessage logic
    OPTIMISM_L1_MESSENGER.relayMessage{gas: _minGasLimit + _SEQUENCER_GAS_OVERHEAD}(
      _messageNonce, _sender, _target, _value, _minGasLimit, _data
    );
    // Needs to be reset to mimic production
    stdstore.target(OPTIMISM_PORTAL).sig('l2Sender()').checked_write(_DEFAULT_L2_SENDER);
  }
}

contract IntegrationSetup is IntegrationBase {
  /**
   * @notice Ensure the setup is correct
   */
  function testSetup() public {
    vm.selectFork(mainnet);
    assertEq(l1Adapter.LINKED_ADAPTER(), address(l2Adapter));

    vm.selectFork(optimism);
    assertEq(l2Adapter.LINKED_ADAPTER(), address(l1Adapter));
    assertEq(l2Adapter.FALLBACK_PROXY_ADMIN().owner(), address(l2Adapter));
  }
}
