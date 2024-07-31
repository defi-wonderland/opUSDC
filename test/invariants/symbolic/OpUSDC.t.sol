// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {HalmosTest} from '../AdvancedTestsUtils.sol';
import {ERC1967Proxy} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import {L1OpUSDCBridgeAdapter} from 'contracts/L1OpUSDCBridgeAdapter.sol';
import {L1OpUSDCFactory} from 'contracts/L1OpUSDCFactory.sol';
import {L2OpUSDCBridgeAdapter} from 'contracts/L2OpUSDCBridgeAdapter.sol';
import {L2OpUSDCDeploy} from 'contracts/L2OpUSDCDeploy.sol';
import {USDC_PROXY_CREATION_CODE} from 'contracts/utils/USDCProxyCreationCode.sol';
import {IOpUSDCBridgeAdapter} from 'interfaces/IOpUSDCBridgeAdapter.sol';
import {IOptimismPortal} from 'interfaces/external/IOptimismPortal.sol';
import {IUSDC} from 'interfaces/external/IUSDC.sol';
import {Create2Deployer} from 'test/invariants/fuzz/Create2Deployer.sol';
import {USDC_IMPLEMENTATION_CREATION_CODE} from 'test/utils/USDCImplementationCreationCode.sol';
import {ITestCrossDomainMessenger} from 'test/utils/interfaces/ITestCrossDomainMessenger.sol';

// solhint-disable
contract OpUsdcTest_SymbTest is HalmosTest {
  IUSDC usdcMainnet;
  IUSDC usdcBridged;

  L1OpUSDCBridgeAdapter internal l1Adapter;
  L1OpUSDCFactory internal factory;

  L2OpUSDCBridgeAdapter internal l2Adapter;
  L2OpUSDCDeploy internal l2Factory;

  MockBridge internal mockMessenger;
  MockPortal internal mockPortal;
  Create2Deployer internal create2Deployer;

  address owner = address(bytes20(keccak256('owner')));
  address usdcMinter = address(bytes20(keccak256('usdc minter')));

  function setUp() public {
    vm.assume(owner != address(0));

    vm.startPrank(owner);

    // Deploy mock messenger
    mockMessenger = new MockBridge();

    // Deploy mock portal
    mockPortal = new MockPortal();

    // Set portal in messenger
    mockMessenger.setPortalAddress(address(mockPortal));

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
    address _l1AdapterImp = address(
      new L1OpUSDCBridgeAdapter(address(usdcMainnet), address(mockMessenger), address(uint160(targetAddress2) + 5))
    );

    l1Adapter = L1OpUSDCBridgeAdapter(
      address(new ERC1967Proxy(_l1AdapterImp, abi.encodeCall(L1OpUSDCBridgeAdapter.initialize, owner)))
    );

    address _l2AdapterImp =
      address(new L2OpUSDCBridgeAdapter(address(usdcBridged), address(mockMessenger), address(l1Adapter)));

    l2Adapter = L2OpUSDCBridgeAdapter(
      address(new ERC1967Proxy(_l2AdapterImp, abi.encodeCall(L2OpUSDCBridgeAdapter.initialize, owner)))
    );

    // usdc l2 init txs
    usdcBridged.changeAdmin(address(l2Adapter.FALLBACK_PROXY_ADMIN()));

    usdcBridged.initialize('Bridged USDC', 'USDC.e', 'USD', 6, owner, address(l2Adapter), address(l2Adapter), owner);

    usdcBridged.configureMinter(address(l2Adapter), type(uint256).max);
    usdcBridged.updateMasterMinter(address(l2Adapter));
    usdcBridged.transferOwnership(address(l2Adapter));

    vm.stopPrank();

    // Allow minting usdc
    vm.prank(usdcMainnet.masterMinter());
    usdcMainnet.configureMinter(address(l1Adapter), type(uint256).max);

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
  /// @dev test in commit history -- Halmos generates a false negative, due to isValidSignatureCall

  /// @custom:property-id 6
  /// @custom:property burn locked only if deprecated
  function check_burnLockedOnlyIfDeprecated(address sender, address rolecaller, address burner, uint256 amt) public {
    // Precondition
    vm.assume(burner != address(0));
    vm.assume(owner != burner);
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
    } catch {
      assert(false);
    }
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
      assert(l1Adapter.messengerStatus() == IOpUSDCBridgeAdapter.Status.Upgrading);
    } catch {
      assert(false);
    }

    // Action
    try l1Adapter.migrateToNative(newRoleCaller, newBurnCaller, 0, 0) {
      // Postcondition
      assert(l1Adapter.burnCaller() == newBurnCaller);
      assert(l1Adapter.messengerStatus() == IOpUSDCBridgeAdapter.Status.Upgrading);
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

    mockMessenger.setDomainMessageSender(address(l2Adapter));
    vm.prank(l1Adapter.MESSENGER());

    // Action
    try l1Adapter.receiveMessage(dest, dest, amt) {
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
  /// @dev test in commit history -- extcodehash representation has an unexpected behavior, seems to behave as a symbolic value (this make a isContract check fail in the OZ Address)

  /// @custom:property-id 14
  /// @custom:property Incoming successful messages should only come from the linked adapter's
  function check_succMessageOnlyFromAdapter(address senderOtherChain) public {
    // Precondition
    mockMessenger.setDomainMessageSender(address(senderOtherChain));

    vm.startPrank(address(mockMessenger));

    // Action
    try l1Adapter.receiveMessage(address(1), address(1), 0) {
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
  /// @dev test in commit history -- Test fails, most likely due to the create computation (trace says addresses are different tho, but not symbolic?)

  /// @custom:property-id 19
  /// @custom:property Adapter cannot be initialized twice
  function check_adapterInitOnce(address caller) public {
    address _newOwner = svm.createAddress('newOwner');

    // l1 adapter
    // Precondition
    vm.prank(caller);

    // Action
    try l1Adapter.initialize(_newOwner) {
      // Postcondition
      assert(false); // cannot happen
    } catch {
      assert(true);
    }

    // l2 adapter
    // Precondition
    vm.prank(caller);

    // Action
    try l2Adapter.initialize(_newOwner) {
      // Postcondition
      assert(false); // cannot happen
    } catch {
      assert(true);
    }
  }

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

  address internal _portal;
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

  function setDomainMessageSender(address _sender) external {
    _currentXDomSender = _sender;
  }

  function setPortalAddress(address _newPortal) external {
    _portal = _newPortal;
  }

  function PORTAL() external view returns (address) {
    return _portal;
  }

  function portal() external view returns (address) {
    return _portal;
  }
}

contract MockPortal is IOptimismPortal {
  function depositTransaction(
    address _to,
    uint256 _value,
    uint64 _gasLimit,
    bool _isCreation,
    bytes memory _data
  ) external payable override {
    // do nothing
  }
}
