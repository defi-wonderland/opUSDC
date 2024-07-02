// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {HalmosTest, HalmosUtils} from '../AdvancedTestsUtils.sol';
import {L1OpUSDCBridgeAdapter} from 'contracts/L1OpUSDCBridgeAdapter.sol';
import {IL1OpUSDCFactory, L1OpUSDCFactory} from 'contracts/L1OpUSDCFactory.sol';
import {L2OpUSDCBridgeAdapter} from 'contracts/L2OpUSDCBridgeAdapter.sol';
import {L2OpUSDCFactory} from 'contracts/L2OpUSDCFactory.sol';
import {USDCInitTxs} from 'contracts/utils/USDCInitTxs.sol';
import {IL2OpUSDCFactory} from 'interfaces/IL2OpUSDCFactory.sol';

import {IOpUSDCBridgeAdapter} from 'interfaces/IOpUSDCBridgeAdapter.sol';
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

    usdcMainnet = IUSDC(targetAddress);
    factory = new L1OpUSDCFactory(address(usdcMainnet));

    // Deploy l2 usdc
    address targetAddress2;
    assembly {
      targetAddress2 := create(0, add(_usdcBytecode, 0x20), size) // Skip the 32 bytes encoded length.
    }

    usdcBridged = IUSDC(targetAddress2);

    // address computedAddress = HalmosUtils.computeCreateAddress(owner, 5); <-- no!
    // Halmos deploy at address + 1, starting at 0xaaaa

    // Deploy l1 adapter
    l1Adapter = new L1OpUSDCBridgeAdapter(
      address(usdcMainnet), address(mockMessenger), address(uint160(targetAddress2) + 2), owner
    );

    l2Adapter = new L2OpUSDCBridgeAdapter(address(usdcBridged), address(mockMessenger), address(l1Adapter), owner);

    // usdc l2 init txs

    usdcBridged.initialize('Bridged USDC', 'USDC.e', 'USD', 6, owner, address(l2Adapter), address(l2Adapter), owner);

    usdcBridged.configureMinter(address(l2Adapter), type(uint256).max);
    usdcBridged.updateMasterMinter(address(l2Adapter));
    usdcBridged.transferOwnership(address(l2Adapter));

    vm.stopPrank();

    // Allow minting usdc
    vm.prank(usdcMainnet.masterMinter());
    usdcMainnet.configureMinter(address(usdcMinter), type(uint256).max);
  }

  // debug: setup
  function check_setup() public view {
    assert(l2Adapter.LINKED_ADAPTER() == address(l1Adapter));
    assert(l2Adapter.MESSENGER() == address(mockMessenger));
    assert(l2Adapter.USDC() == address(usdcBridged));

    assert(l1Adapter.LINKED_ADAPTER() == address(l2Adapter));
    assert(l1Adapter.MESSENGER() == address(mockMessenger));
    assert(l1Adapter.USDC() == address(usdcMainnet));
  }

  // | New messages should not be sent if the state is not active| Unit test           | 1   | [X]  | [ ]  |
  function check_noNewMsgIfNotActiveL1(address dest, uint256 amt, uint32 minGas) public {
    // Precondition
    // messaging is inactive
    vm.prank(owner);
    l1Adapter.stopMessaging(minGas);

    // Action
    try l1Adapter.sendMessage(dest, amt, minGas) {
      // Postcondition
      assert(false);
    } catch {}
  }

  function check_noNewMsgIfNotActiveL2(address dest, uint256 amt, uint32 minGas) public {
    // Precondition
    // messaging is inactive (use the bridge for the caller auth)
    vm.prank(address(l1Adapter));
    mockMessenger.sendMessage(address(l2Adapter), abi.encodeWithSignature('receiveStopMessaging()'), minGas);

    // Action
    try l2Adapter.sendMessage(dest, amt, minGas) {
      // Postcondition
      assert(false);
    } catch {}
  }

  // | User who bridges tokens should receive them on the destination chain                                        | High level          | 2   | [X]  | [ ]  |
  // | Assuming the adapter is the only minter the amount locked in L1 should always equal the amount minted on L2 | High level          | 3   | [X]  | [ ]  |
  function check_messageReceivedL2(address sender, address dest, uint256 amt, uint32 minGas) public {
    // Precondition
    vm.assume(amt > 0); // cannot mint 0 usdc
    vm.assume(usdcMainnet.balanceOf(dest) < 2 ** 255 - 1 - amt); // usdc max supply
    vm.assume(usdcBridged.balanceOf(dest) < 2 ** 255 - 1 - amt);
    vm.assume(usdcMainnet.balanceOf(sender) < 2 ** 255 - 1 - amt);
    vm.assume(usdcMainnet.balanceOf(address(l1Adapter)) < 2 ** 255 - 1 - amt);

    vm.assume(dest != address(0) && dest != address(usdcMainnet) && dest != address(usdcBridged)); // blacklisted addresses
    vm.assume(sender != address(0) && sender != address(usdcMainnet) && sender != address(usdcBridged));

    vm.prank(usdcMinter);
    usdcMainnet.mint(sender, amt);

    usdcMainnet.balanceOf(sender);

    vm.startPrank(sender);
    usdcMainnet.approve(address(l1Adapter), amt);

    // Action
    l1Adapter.sendMessage(dest, amt, minGas);

    // Postcondition
    assert(usdcBridged.balanceOf(dest) == amt);
    assert(usdcMainnet.balanceOf(address(l1Adapter)) == usdcBridged.totalSupply());
  }

  // todo: false negative!!
  function check_nonceMonotonicallyIncreases(uint256 numberMessages, address dest, uint256 amt) public {
    // Precondition
    (address sender, uint256 privateKey) = makeAddrAndKey('sender');

    vm.assume(sender != address(0) && dest != address(0) && amt > 0);

    uint256 nonceBefore = l1Adapter.userNonce(sender);

    bytes32 digest =
      keccak256(abi.encode(l1Adapter, block.chainid, dest, amt, nonceBefore + 1)).toEthSignedMessageHash();
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
    bytes memory signature = abi.encodePacked(r, s, v);

    // Action
    for (uint256 i = 0; i < numberMessages; i++) {
      l1Adapter.sendMessage(sender, dest, amt, signature, block.timestamp + 1000, 0);
    }

    // Postcondition
    assert(l1Adapter.userNonce(sender) == nonceBefore + numberMessages);
  }
}

// Atomically transmit any message
contract MockBridge is ITestCrossDomainMessenger {
  uint256 public messageNonce;
  address public l1Adapter;

  address internal _currentXDomSender;

  function OTHER_MESSENGER() external pure returns (address) {
    return address(0);
  }

  function xDomainMessageSender() external view returns (address) {
    return _currentXDomSender;
  }

  function sendMessage(address _target, bytes calldata _message, uint32) external {
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
    _currentXDomSender = msg.sender;
    messageNonce++;
    (bool succ, bytes memory ret) = _target.call{value: _value}(_message);
    if (!succ) revert(string(ret));
  }

  function setDomaninMessageSender(address _sender) external {
    _currentXDomSender = _sender;
  }
}
