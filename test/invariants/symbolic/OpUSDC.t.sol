// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {HalmosTest, HalmosUtils} from '../AdvancedTestsUtils.sol';

import {IL1OpUSDCBridgeAdapter, L1OpUSDCBridgeAdapter} from 'contracts/L1OpUSDCBridgeAdapter.sol';
import {IL1OpUSDCFactory, L1OpUSDCFactory} from 'contracts/L1OpUSDCFactory.sol';
import {FallbackProxyAdmin, L2OpUSDCBridgeAdapter} from 'contracts/L2OpUSDCBridgeAdapter.sol';

import {L2OpUSDCFactory} from 'contracts/L2OpUSDCFactory.sol';

import {USDCInitTxs} from 'contracts/utils/USDCInitTxs.sol';
import {USDC_PROXY_CREATION_CODE} from 'contracts/utils/USDCProxyCreationCode.sol';
import {IUSDC} from 'interfaces/external/IUSDC.sol';
import {USDC_IMPLEMENTATION_CREATION_CODE} from 'script/utils/USDCImplementationCreationCode.sol';
import {Create2Deployer} from 'test/invariants/fuzz/Create2Deployer.sol';
import {ITestCrossDomainMessenger} from 'test/utils/interfaces/ITestCrossDomainMessenger.sol';

import {MessageHashUtils} from '@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol';

contract OpUsdcTest_SymbTest is HalmosTest {
  using MessageHashUtils for bytes32;

  IUSDC usdcMainnet;
  IUSDC usdcBridged;

  L1OpUSDCBridgeAdapter internal l1Adapter;
  L1OpUSDCFactory internal factory;

  L2OpUSDCBridgeAdapter internal l2Adapter;
  L2OpUSDCFactory internal l2Factory;

  MockBridge internal mockMessenger;
  Create2Deployer internal create2Deployer;

  address owner = address(bytes20(keccak256('owner')));
  address usdcMinter = address(bytes20(keccak256('usdc minter')));

  function setUp() public {
    vm.assume(owner != address(0));

    vm.startPrank(owner);

    // Deploy mock messenger
    mockMessenger = new MockBridge();

    // Deploy l1 factory
    address targetAddress;

    uint256 size = USDC_IMPLEMENTATION_CREATION_CODE.length;
    bytes memory _usdcBytecode = USDC_IMPLEMENTATION_CREATION_CODE;

    assembly {
      targetAddress := create(0, add(_usdcBytecode, 0x20), size) // Skip the 32 bytes encoded length.
    }

    assert(targetAddress != address(0));

    usdcMainnet = IUSDC(targetAddress);

    factory = new L1OpUSDCFactory(address(usdcMainnet));

    // Deploy l2 usdc and proxy
    address targetAddress2;

    assembly {
      targetAddress2 := create(0, add(_usdcBytecode, 0x20), size) // Skip the 32 bytes encoded length.
    }

    assert(targetAddress2 != address(0));

    address targetProxy;
    bytes memory _usdcProxyCArgs = abi.encode(targetAddress2);
    bytes memory _usdcProxyInitCode = bytes.concat(USDC_PROXY_CREATION_CODE, _usdcProxyCArgs);
    uint256 sizeProxy = _usdcProxyInitCode.length;

    assembly {
      targetProxy := create(0, add(_usdcProxyInitCode, 0x20), sizeProxy) // Skip the 32 bytes encoded length.
    }

    assert(targetProxy != address(0));

    usdcBridged = IUSDC(targetProxy);

    // address computedAddress = HalmosUtils.computeCreateAddress(owner, 5); <-- no! create logic isn't supported, due to symbolic keccak oputput
    // Halmos deploy at address + 1, starting at 0xaaaa0000

    // Deploy l1 adapter
    l1Adapter = new L1OpUSDCBridgeAdapter(
      address(usdcMainnet), address(mockMessenger), address(uint160(targetAddress2) + 3), owner
    );

    l2Adapter = new L2OpUSDCBridgeAdapter(address(usdcBridged), address(mockMessenger), address(l1Adapter), owner);

    // usdc l2 init txs
    usdcBridged.changeAdmin(address(l2Adapter.FALLBACK_PROXY_ADMIN()));

    usdcBridged.initialize('Bridged USDC', 'USDC.e', 'USD', 6, owner, address(l2Adapter), address(l2Adapter), owner);

    usdcBridged.configureMinter(address(l2Adapter), type(uint256).max);
    usdcBridged.updateMasterMinter(address(l2Adapter));
    usdcBridged.transferOwnership(address(l2Adapter));

    vm.stopPrank();

    // Allow minting usdc
    vm.prank(usdcMainnet.masterMinter());
    usdcMainnet.configureMinter(address(usdcMinter), type(uint256).max);
  }

  /// @custom:property-id 0
  /// @custom:property Setup should be correct
  function check_setup() public view {
    assert(l2Adapter.LINKED_ADAPTER() == address(l1Adapter));
    assert(l2Adapter.MESSENGER() == address(mockMessenger));
    assert(l2Adapter.USDC() == address(usdcBridged));
    assert(address(l2Adapter.FALLBACK_PROXY_ADMIN()) != address(0));
    assert(usdcBridged.admin() == address(l2Adapter.FALLBACK_PROXY_ADMIN()));

    assert(l1Adapter.LINKED_ADAPTER() == address(l2Adapter));
    assert(l1Adapter.MESSENGER() == address(mockMessenger));
    assert(l1Adapter.USDC() == address(usdcMainnet));
  }

  /// @custom:property-id 1
  /// @custom:property New messages should not be sent if the state is not active
  function check_noNewMsgIfNotActiveL1(address dest, uint256 amt, uint32 minGas) public {
    // Precondition
    // messaging is inactive
    vm.prank(owner);
    l1Adapter.stopMessaging(minGas);

    // Action
    try l1Adapter.sendMessage(dest, amt, minGas) {
      // Postcondition
      assert(false); // cannot happen
    } catch {}
  }

  /// @custom:property-id 1
  /// @custom:property New messages should not be sent if the state is not active
  function check_noNewMsgIfNotActiveL2(address dest, uint256 amt, uint32 minGas) public {
    // Precondition
    // L2 messaging is inactive (use the bridge for the caller auth)
    vm.prank(address(l1Adapter));
    mockMessenger.sendMessage(address(l2Adapter), abi.encodeWithSignature('receiveStopMessaging()'), minGas);

    // Action
    try l2Adapter.sendMessage(dest, amt, minGas) {
      // Postcondition
      assert(false); // cannot happen
    } catch {}
  }

  /// @custom:property-id 2
  /// @custom:property User who bridges tokens should receive them on the destination chain
  /// @custom:property-id 3
  /// @custom:property Assuming the adapter is the only minter the amount locked in L1 should always equal the amount minted on L2
  function check_messageReceivedL2(address sender, address dest, uint256 amt, uint32 minGas) public {
    // Precondition
    _mainnetMint(sender, amt);

    vm.assume(usdcMainnet.balanceOf(sender) < 2 ** 255 - 1 - amt);
    vm.assume(usdcMainnet.balanceOf(address(l1Adapter)) < 2 ** 255 - 1 - amt);

    vm.assume(dest != address(0) && dest != address(usdcMainnet) && dest != address(usdcBridged));

    vm.startPrank(sender);
    usdcMainnet.approve(address(l1Adapter), amt);

    // Action
    l1Adapter.sendMessage(dest, amt, minGas);

    // Postcondition
    assert(usdcBridged.balanceOf(dest) == amt);
    assert(usdcMainnet.balanceOf(address(l1Adapter)) == usdcBridged.totalSupply());
  }

  /// @custom:property-id 5
  /// @custom:property Nonce should increase monotonically for each user
  /// @custom:property-not-tested
  // -- Halmos generates a false negative, due to isValidSignatureCall
  // function check_nonceMonotonicallyIncreases(uint256 numberMessages, address dest, uint256 amt) public {
  //   // Precondition
  //   (address sender, uint256 privateKey) = makeAddrAndKey('sender');

  //   vm.assume(sender != address(0) && dest != address(0) && amt > 0);

  //   uint256 nonceBefore = l1Adapter.userNonce(sender);

  //   bytes32 digest =
  //     keccak256(abi.encode(l1Adapter, block.chainid, dest, amt, nonceBefore + 1)).toEthSignedMessageHash();
  //   (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
  //   bytes memory signature = abi.encodePacked(r, s, v);

  //   // Action
  //   for (uint256 i = 0; i < numberMessages; i++) {
  //     l1Adapter.sendMessage(sender, dest, amt, signature, block.timestamp + 1000, 0);
  //   }

  //   // Postcondition
  //   assert(l1Adapter.userNonce(sender) == nonceBefore + numberMessages);
  // }

  /// @custom:property-id 6
  /// @custom:property burn locked only if deprecated
  function check_burnLockedOnlyIfDeprecated(address sender, address rolecaller, address burner, uint256 amt) public {
    // Precondition
    vm.assume(burner != address(0));
    _mainnetMint(sender, amt);

    vm.startPrank(sender);
    usdcMainnet.approve(address(l1Adapter), amt);
    l1Adapter.sendMessage(sender, amt, 0);
    vm.stopPrank();

    // No burn before migration
    vm.startPrank(owner);
    // Action
    try l1Adapter.burnLockedUSDC() {
      // Postcondition
      assert(false); // This should not happen
    } catch {}

    // Owner cannot burn
    // Precondition
    l1Adapter.migrateToNative(rolecaller, burner, 0, 0);

    // Action
    try l1Adapter.burnLockedUSDC() {
      // Postcondition
      assert(false); // Owner cannot burn
    } catch {}

    // Burner can burn
    // Precondition
    vm.stopPrank();
    vm.prank(burner);

    // Action
    try l1Adapter.burnLockedUSDC() {
      // Postcondition
      assert(usdcMainnet.balanceOf(address(l1Adapter)) == 0);
      assert(l1Adapter.burnCaller() == address(0));
    } catch {}
  }

  /// @custom:property-id 11
  /// @custom:property  Upgrading state only via migrate to native, should be callable multiple times (if crosschain msg fails)
  function check_multipleMigrateCalls() public {
    // Precondition
    address burnCaller = svm.createAddress('newBurnCaller');
    address newBurnCaller = svm.createAddress('newBurnCaller');
    address roleCaller = svm.createAddress('newRoleCaller');
    address newRoleCaller = svm.createAddress('newRoleCaller');

    vm.assume(
      burnCaller != address(0) && newBurnCaller != address(0) && roleCaller != address(0) && newRoleCaller != address(0)
    );

    mockMessenger.stopMessageRelay(); // Insure we don't trigger the whole migration as the mock bridge is atomic

    vm.startPrank(owner);
    try l1Adapter.migrateToNative(roleCaller, burnCaller, 0, 0) {
      assert(l1Adapter.burnCaller() == burnCaller);
      assert(l1Adapter.messengerStatus() == IL1OpUSDCBridgeAdapter.Status.Upgrading);
    } catch {
      assert(false);
    }

    // Action
    try l1Adapter.migrateToNative(newRoleCaller, newBurnCaller, 0, 0) {
      // Postcondition
      assert(l1Adapter.burnCaller() == newBurnCaller);
      assert(l1Adapter.messengerStatus() == IL1OpUSDCBridgeAdapter.Status.Upgrading);
    } catch {
      assert(false);
    }
  }

  /// @custom:property-id 12
  /// @custom:property All in flight transactions should successfully settle after a migration to native usdc
  function check_settleWhenUpgraded(address dest, uint256 amt) public {
    // Precondition
    _mainnetMint(address(l1Adapter), amt);
    address burnCaller = svm.createAddress('newBurnCaller');
    address roleCaller = svm.createAddress('newRoleCaller');

    vm.assume(burnCaller != address(0) && roleCaller != address(0) && dest != address(0));
    vm.assume(dest != address(l1Adapter)); // for correct postcondition checks

    vm.prank(owner);
    l1Adapter.migrateToNative(roleCaller, burnCaller, 0, 0);

    uint256 _destBalanceBefore = usdcMainnet.balanceOf(dest);
    vm.assume(_destBalanceBefore < 2 ** 255 - 1 - amt);

    uint256 _l1AdapterBalanceBefore = usdcMainnet.balanceOf(address(l1Adapter));

    mockMessenger.setDomaninMessageSender(address(l2Adapter));
    vm.prank(l1Adapter.MESSENGER());

    // Action
    try l1Adapter.receiveMessage(dest, amt) {
      // Postcondition
      assert(usdcMainnet.balanceOf(dest) == _destBalanceBefore + amt);
      assert(usdcMainnet.balanceOf(address(l1Adapter)) == _l1AdapterBalanceBefore - amt);
    } catch {
      assert(false);
    }
  }

  /// @custom:property-id 13
  /// @custom:property Bridged USDC Proxy should only be upgradeable through the L2 Adapter
  /// @custom:property-not-tested
  // -- extcodehash representation has an unexpected behavior, seems to behave as a symbolic value (this make a isContract check fail in the OZ Address)
  // function check_usdceProxyOnlyUpgradeableThroughL2Adapter(address caller) public {
  //   // Precondition
  //   address newImplementation = address(new MockBridge());

  //   vm.startPrank(caller);

  //   // Action
  //   try FallbackProxyAdmin(l2Adapter.FALLBACK_PROXY_ADMIN()).upgradeTo(newImplementation) {
  //     // Postcondition
  //     assert(caller == address(l2Adapter));
  //   } catch {
  //     assert(caller != address(l2Adapter));
  //   }
  // }

  /// @custom:property-id 14
  /// @custom:property Incoming successful messages should only come from the linked adapter's
  function check_succMessageOnlyFromAdapter(address senderOtherChain) public {
    // Precondition
    mockMessenger.setDomaninMessageSender(address(senderOtherChain));

    vm.startPrank(address(mockMessenger));

    // Action
    try l1Adapter.receiveMessage(address(1), 0) {
      // Postcondition
      assert(senderOtherChain == address(l2Adapter));
    } catch {
      assert(senderOtherChain != address(l2Adapter));
    }
  }

  /// @custom:property-id 15
  /// @custom:property Any chain should be able to have as many protocols deployed without the factory blocking deployments
  /// @custom:property-not-tested
  /// @custom:property-id 16
  /// @custom:property Protocols deployed on one L2 should never have a matching address with a protocol on a different L2
  /// @custom:property-not-tested
  // -- Test fails, most likely due to the create computation (trace says addresses are different tho, but not symbolic?)
  // function check_uniqueAddresses() public {
  //   // Precondition
  //   mockMessenger.stopMessageRelay();

  //   bytes[] memory usdcInitTxns = new bytes[](3);
  //   usdcInitTxns[0] = USDCInitTxs.INITIALIZEV2;
  //   usdcInitTxns[1] = USDCInitTxs.INITIALIZEV2_1;
  //   usdcInitTxns[2] = USDCInitTxs.INITIALIZEV2_2;

  //   IL1OpUSDCFactory.L2Deployments memory _l2Deployments = IL1OpUSDCFactory.L2Deployments(address(123), USDC_IMPLEMENTATION_CREATION_CODE, usdcInitTxns, 3_000_000);
  //   (address _l1Adapter, address _l2Factory, address _l2Adapter) = factory.deploy(address(mockMessenger), address(123), _l2Deployments);

  //   // Action
  //   try factory.deploy(address(mockMessenger), address(123), _l2Deployments) returns (address _secondL1Adapter, address _secondL2Factory, address _secondL2Adapter) {
  //     // Postcondition
  //     assert(_l1Adapter == _secondL1Adapter);
  //     assert(_l2Factory != _secondL2Factory);
  //     assert(_l2Adapter != _secondL2Adapter);
  //   } catch {
  //     assert(false); // Can never revert
  //   }
  // }

  /// @dev Mint arbitrary amount of USDC on mainnet to dest
  function _mainnetMint(address dest, uint256 amt) internal {
    vm.assume(amt > 0); // cannot mint 0 usdc
    vm.assume(usdcMainnet.balanceOf(dest) < 2 ** 255 - 1 - amt); // usdc max supply
    vm.assume(usdcBridged.balanceOf(dest) < 2 ** 255 - 1 - amt);

    vm.assume(dest != address(0) && dest != address(usdcMainnet) && dest != address(usdcBridged)); // blacklisted addresses

    vm.prank(usdcMinter);
    usdcMainnet.mint(dest, amt);
  }
}

/// @dev Mock a messaging bridge which atomically transmit any message
contract MockBridge is ITestCrossDomainMessenger {
  uint256 public messageNonce;
  address public l1Adapter;

  address internal _currentXDomSender;
  bool internal _bridgeStopped;

  function OTHER_MESSENGER() external pure returns (address) {
    return address(0);
  }

  function xDomainMessageSender() external view returns (address) {
    return _currentXDomSender;
  }

  function sendMessage(address _target, bytes calldata _message, uint32) external {
    if (_bridgeStopped) return;

    messageNonce++;
    bytes memory __message = _message;
    _currentXDomSender = msg.sender;
    assembly {
      pop(call(gas(), _target, 0, add(__message, 0x20), mload(__message), 0, 0))
    }
  }

  function relayMessage(
    uint256,
    address,
    address _target,
    uint256 _value,
    uint256,
    bytes calldata _message
  ) external payable {
    if (_bridgeStopped) return;

    _currentXDomSender = msg.sender;
    messageNonce++;
    (bool succ, bytes memory ret) = _target.call{value: _value}(_message);
    if (!succ) revert(string(ret));
  }

  function stopMessageRelay() external {
    _bridgeStopped = true;
  }

  function setDomaninMessageSender(address _sender) external {
    _currentXDomSender = _sender;
  }
}
