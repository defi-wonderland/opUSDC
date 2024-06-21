// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IntegrationBase} from './IntegrationBase.sol';
import {StdStorage, stdStorage} from 'forge-std/StdStorage.sol';
import {IL1OpUSDCBridgeAdapter} from 'interfaces/IL1OpUSDCBridgeAdapter.sol';
import {IOpUSDCBridgeAdapter} from 'interfaces/IOpUSDCBridgeAdapter.sol';
import {AddressAliasHelper} from 'test/utils/AddressAliasHelper.sol';

contract Integration_Bridging is IntegrationBase {
  /**
   * @notice Test the bridging process from L1 -> L2
   */
  function test_bridgeFromL1() public {
    vm.selectFork(mainnet);

    deal(address(MAINNET_USDC), _user, _amount);

    vm.startPrank(_user);
    MAINNET_USDC.approve(address(l1Adapter), _amount);
    l1Adapter.sendMessage(_user, _amount, _minGasLimit);
    vm.stopPrank();

    assertEq(MAINNET_USDC.balanceOf(_user), 0);
    assertEq(MAINNET_USDC.balanceOf(address(l1Adapter)), _amount);

    vm.selectFork(optimism);
    uint256 _messageNonce = L2_MESSENGER.messageNonce();

    vm.startPrank(AddressAliasHelper.applyL1ToL2Alias(address(OPTIMISM_L1_MESSENGER)));
    L2_MESSENGER.relayMessage(
      _messageNonce + 1,
      address(l1Adapter),
      address(l2Adapter),
      0,
      1_000_000,
      abi.encodeWithSignature('receiveMessage(address,uint256)', _user, _amount)
    );
    vm.stopPrank();

    assertEq(bridgedUSDC.balanceOf(address(_user)), _amount);
  }

  /**
   * @notice Test the bridging process from L1 -> L2 with a different target
   */
  function test_bridgeFromL1DifferentTarget() public {
    vm.selectFork(mainnet);

    address _l2Target = makeAddr('l2Target');

    deal(address(MAINNET_USDC), _user, _amount);

    vm.startPrank(_user);
    MAINNET_USDC.approve(address(l1Adapter), _amount);
    l1Adapter.sendMessage(_l2Target, _amount, _minGasLimit);
    vm.stopPrank();

    assertEq(MAINNET_USDC.balanceOf(_user), 0);
    assertEq(MAINNET_USDC.balanceOf(address(l1Adapter)), _amount);

    vm.selectFork(optimism);
    uint256 _messageNonce = L2_MESSENGER.messageNonce();

    vm.startPrank(AddressAliasHelper.applyL1ToL2Alias(address(OPTIMISM_L1_MESSENGER)));
    L2_MESSENGER.relayMessage(
      _messageNonce + 1,
      address(l1Adapter),
      address(l2Adapter),
      0,
      1_000_000,
      abi.encodeWithSignature('receiveMessage(address,uint256)', _l2Target, _amount)
    );
    vm.stopPrank();

    assertEq(bridgedUSDC.balanceOf(address(_l2Target)), _amount);
    assertEq(bridgedUSDC.balanceOf(address(_user)), 0);
  }

  /**
   * @notice Test bridging with signature
   */
  function test_bridgeFromL1WithSig() public {
    (address _signerAd, uint256 _signerPk) = makeAddrAndKey('signer');
    vm.selectFork(mainnet);

    deal(address(MAINNET_USDC), _signerAd, _amount);

    // Minting for user to check its not spent when they execute
    deal(address(MAINNET_USDC), _user, _amount);

    vm.prank(_signerAd);
    MAINNET_USDC.approve(address(l1Adapter), _amount);

    uint256 _nonce = vm.getNonce(_signerAd);
    bytes memory _signature = _generateSignature(_signerAd, _amount, _nonce, _signerAd, _signerPk, address(l1Adapter));
    uint256 _deadline = block.timestamp + 1 days;

    // Different address can execute the message
    vm.startPrank(_user);
    l1Adapter.sendMessage(_signerAd, _signerAd, _amount, _signature, _deadline, _minGasLimit);
    vm.stopPrank();

    assertEq(MAINNET_USDC.balanceOf(_signerAd), 0);
    assertEq(MAINNET_USDC.balanceOf(_user), _amount);
    assertEq(MAINNET_USDC.balanceOf(address(l1Adapter)), _amount);

    vm.selectFork(optimism);
    uint256 _messageNonce = L2_MESSENGER.messageNonce();

    vm.startPrank(AddressAliasHelper.applyL1ToL2Alias(address(OPTIMISM_L1_MESSENGER)));
    L2_MESSENGER.relayMessage(
      _messageNonce + 1,
      address(l1Adapter),
      address(l2Adapter),
      0,
      1_000_000,
      abi.encodeWithSignature('receiveMessage(address,uint256)', _signerAd, _amount)
    );
    vm.stopPrank();

    assertEq(bridgedUSDC.balanceOf(address(_signerAd)), _amount);
    assertEq(bridgedUSDC.balanceOf(address(_user)), 0);
  }

  /**
   * @notice Test signature message reverts with incorrect signature
   */
  function test_bridgeFromL1WithIncorrectSignature() public {
    (address _signerAd, uint256 _signerPk) = makeAddrAndKey('signer');
    vm.selectFork(mainnet);

    deal(address(MAINNET_USDC), _signerAd, _amount);

    vm.prank(_signerAd);
    MAINNET_USDC.approve(address(l1Adapter), _amount);

    uint256 _nonce = vm.getNonce(_signerAd);

    // Changing to `to` param to _user but we call it with _signerAd
    bytes memory _signature = _generateSignature(_user, _amount, _nonce, _signerAd, _signerPk, address(l1Adapter));
    uint256 _deadline = block.timestamp + 1 days;

    // Different address can execute the message
    vm.startPrank(_user);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidSignature.selector);
    l1Adapter.sendMessage(_signerAd, _signerAd, _amount, _signature, _deadline, _minGasLimit);
    vm.stopPrank();
  }
}

contract Integration_Migration is IntegrationBase {
  using stdStorage for StdStorage;

  address internal _circle = makeAddr('circle');
  uint32 internal _minGasLimitReceiveOnL2 = 1_000_000;
  uint32 internal _minGasLimitSetBurnAmount = 1_000_000;

  function setUp() public override {
    super.setUp();

    _mintSupplyOnL2(_amount);

    vm.selectFork(mainnet);
    // Adapter needs to be minter to burn
    vm.startPrank(MAINNET_USDC.masterMinter());
    MAINNET_USDC.configureMinter(address(l1Adapter), 0);
    vm.stopPrank();
  }

  /**
   * @notice Test the migration to native usdc flow
   */
  function test_migrationToNativeUSDC() public {
    vm.selectFork(mainnet);

    vm.startPrank(_owner);
    l1Adapter.migrateToNative(_circle, _minGasLimitReceiveOnL2, _minGasLimitSetBurnAmount);
    vm.stopPrank();

    assertEq(uint256(l1Adapter.messengerStatus()), uint256(IL1OpUSDCBridgeAdapter.Status.Upgrading));
    assertEq(l1Adapter.newOwner(), _circle);

    vm.selectFork(optimism);

    uint256 _messageNonce = L2_MESSENGER.messageNonce();
    vm.startPrank(AddressAliasHelper.applyL1ToL2Alias(address(OPTIMISM_L1_MESSENGER)));
    L2_MESSENGER.relayMessage(
      _messageNonce + 1,
      address(l1Adapter),
      address(l2Adapter),
      0,
      _minGasLimitReceiveOnL2,
      abi.encodeWithSignature('receiveMigrateToNative(address,uint32)', _circle, _minGasLimitSetBurnAmount)
    );
    vm.stopPrank();

    uint256 _burnAmount = bridgedUSDC.totalSupply();

    assertEq(l2Adapter.isMessagingDisabled(), true);
    assertEq(bridgedUSDC.owner(), _circle);

    vm.selectFork(mainnet);
    _messageNonce = OPTIMISM_L1_MESSENGER.messageNonce();

    // For simplicity we do this as this slot is not exposed until prove and finalize is done
    stdstore.target(OPTIMISM_PORTAL).sig('l2Sender()').checked_write(address(L2_MESSENGER));

    vm.startPrank(OPTIMISM_PORTAL);
    OPTIMISM_L1_MESSENGER.relayMessage(
      _messageNonce + 1,
      address(l2Adapter),
      address(l1Adapter),
      0,
      _minGasLimitSetBurnAmount,
      abi.encodeWithSignature('setBurnAmount(uint256)', _burnAmount)
    );
    vm.stopPrank();

    assertEq(l1Adapter.burnAmount(), _burnAmount);
    assertEq(l1Adapter.USDC(), address(MAINNET_USDC));
    assertEq(uint256(l1Adapter.messengerStatus()), uint256(IL1OpUSDCBridgeAdapter.Status.Deprecated));

    vm.startPrank(_circle);
    l1Adapter.burnLockedUSDC();
    vm.stopPrank();

    assertEq(MAINNET_USDC.balanceOf(address(l1Adapter)), 0);
    assertEq(l1Adapter.burnAmount(), 0);
    assertEq(l1Adapter.newOwner(), address(0));
  }
}

contract Integration_Integration_PermissionedFlows is IntegrationBase {
  /**
   * @notice Test that the messaging is stopped and resumed correctly from L1 on
   * both layers
   */
  function test_stopAndResumeMessaging() public {
    vm.selectFork(mainnet);

    assertEq(uint256(l1Adapter.messengerStatus()), uint256(IL1OpUSDCBridgeAdapter.Status.Active));

    vm.prank(_owner);
    l1Adapter.stopMessaging(_minGasLimit);

    assertEq(uint256(l1Adapter.messengerStatus()), uint256(IL1OpUSDCBridgeAdapter.Status.Paused));

    vm.selectFork(optimism);
    uint256 _messageNonce = L2_MESSENGER.messageNonce();

    vm.prank(AddressAliasHelper.applyL1ToL2Alias(address(OPTIMISM_L1_MESSENGER)));
    L2_MESSENGER.relayMessage(
      _messageNonce + 1,
      address(l1Adapter),
      address(l2Adapter),
      0,
      _minGasLimit,
      abi.encodeWithSignature('receiveStopMessaging()')
    );

    assertEq(l2Adapter.isMessagingDisabled(), true);

    vm.selectFork(mainnet);

    vm.prank(_owner);
    l1Adapter.resumeMessaging(_minGasLimit);

    assertEq(uint256(l1Adapter.messengerStatus()), uint256(IL1OpUSDCBridgeAdapter.Status.Active));

    vm.selectFork(optimism);

    vm.prank(AddressAliasHelper.applyL1ToL2Alias(address(OPTIMISM_L1_MESSENGER)));
    L2_MESSENGER.relayMessage(
      _messageNonce + 2,
      address(l1Adapter),
      address(l2Adapter),
      0,
      _minGasLimit,
      abi.encodeWithSignature('receiveResumeMessaging()')
    );

    assertEq(l2Adapter.isMessagingDisabled(), false);
  }
}
