// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IntegrationBase} from './IntegrationBase.sol';
import {IL1OpUSDCBridgeAdapter} from 'interfaces/IL1OpUSDCBridgeAdapter.sol';
import {IOpUSDCBridgeAdapter} from 'interfaces/IOpUSDCBridgeAdapter.sol';

contract Integration_Bridging is IntegrationBase {
  /**
   * @notice Test the bridging process from L1 -> L2
   */
  function test_bridgeFromL1() public {
    vm.selectFork(mainnet);

    // We need to do this instead of `deal` because deal doesnt change `totalSupply` state
    vm.prank(MAINNET_USDC.masterMinter());
    MAINNET_USDC.mint(_user, _amount);

    vm.startPrank(_user);
    MAINNET_USDC.approve(address(l1Adapter), _amount);
    l1Adapter.sendMessage(_user, _amount, _MIN_GAS_LIMIT);
    vm.stopPrank();

    assertEq(MAINNET_USDC.balanceOf(_user), 0);
    assertEq(MAINNET_USDC.balanceOf(address(l1Adapter)), _amount);

    vm.selectFork(optimism);
    uint256 _userBalanceBefore = bridgedUSDC.balanceOf(_user);

    _relayL1ToL2Message(
      OP_ALIASED_L1_MESSENGER,
      address(l1Adapter),
      address(l2Adapter),
      _ZERO_VALUE,
      1_000_000,
      abi.encodeWithSignature('receiveMessage(address,uint256)', _user, _amount)
    );

    assertEq(bridgedUSDC.balanceOf(_user), _userBalanceBefore + _amount);
  }

  /**
   * @notice Test the bridging process from L1 -> L2 with a different target
   */
  function test_bridgeFromL1DifferentTarget() public {
    vm.selectFork(mainnet);

    address _l2Target = makeAddr('l2Target');

    // We need to do this instead of `deal` because deal doesnt change `totalSupply` state
    vm.prank(MAINNET_USDC.masterMinter());
    MAINNET_USDC.mint(_user, _amount);

    vm.startPrank(_user);
    MAINNET_USDC.approve(address(l1Adapter), _amount);
    l1Adapter.sendMessage(_l2Target, _amount, _MIN_GAS_LIMIT);
    vm.stopPrank();

    assertEq(MAINNET_USDC.balanceOf(_user), 0);
    assertEq(MAINNET_USDC.balanceOf(address(l1Adapter)), _amount);

    vm.selectFork(optimism);
    uint256 _userBalanceBefore = bridgedUSDC.balanceOf(_user);
    _relayL1ToL2Message(
      OP_ALIASED_L1_MESSENGER,
      address(l1Adapter),
      address(l2Adapter),
      _ZERO_VALUE,
      1_000_000,
      abi.encodeWithSignature('receiveMessage(address,uint256)', _l2Target, _amount)
    );

    assertEq(bridgedUSDC.balanceOf(_l2Target), _userBalanceBefore + _amount);
    assertEq(bridgedUSDC.balanceOf(_user), 0);
  }

  /**
   * @notice Test bridging with signature
   */
  function test_bridgeFromL1WithSig() public {
    (address _signerAd, uint256 _signerPk) = makeAddrAndKey('signer');
    vm.selectFork(mainnet);

    // We need to do this instead of `deal` because deal doesnt change `totalSupply` state
    vm.startPrank(MAINNET_USDC.masterMinter());
    MAINNET_USDC.mint(_signerAd, _amount);
    // Minting for user to check its not spent when they execute
    // We need to do this instead of `deal` because deal doesnt change `totalSupply` state
    MAINNET_USDC.mint(_user, _amount);
    vm.stopPrank();

    vm.prank(_signerAd);
    MAINNET_USDC.approve(address(l1Adapter), _amount);
    uint256 _deadline = block.timestamp + 1 days;
    uint256 _nonce = vm.getNonce(_signerAd);
    bytes memory _signature =
      _generateSignature(_signerAd, _amount, _deadline, _nonce, _signerAd, _signerPk, address(l1Adapter));

    // Different address can execute the message
    vm.prank(_user);
    l1Adapter.sendMessage(_signerAd, _signerAd, _amount, _signature, _deadline, _MIN_GAS_LIMIT);

    assertEq(MAINNET_USDC.balanceOf(_signerAd), 0);
    assertEq(MAINNET_USDC.balanceOf(_user), _amount);
    assertEq(MAINNET_USDC.balanceOf(address(l1Adapter)), _amount);

    vm.selectFork(optimism);
    uint256 _userBalanceBefore = bridgedUSDC.balanceOf(_user);
    _relayL1ToL2Message(
      OP_ALIASED_L1_MESSENGER,
      address(l1Adapter),
      address(l2Adapter),
      _ZERO_VALUE,
      1_000_000,
      abi.encodeWithSignature('receiveMessage(address,uint256)', _signerAd, _amount)
    );

    assertEq(bridgedUSDC.balanceOf(_signerAd), _userBalanceBefore + _amount);
    assertEq(bridgedUSDC.balanceOf(_user), 0);
  }

  /**
   * @notice Test signature message reverts with incorrect signature
   */
  function test_bridgeFromL1WithIncorrectSignature() public {
    (address _signerAd, uint256 _signerPk) = makeAddrAndKey('signer');
    vm.selectFork(mainnet);

    // We need to do this instead of `deal` because deal doesnt change `totalSupply` state
    vm.prank(MAINNET_USDC.masterMinter());
    MAINNET_USDC.mint(_signerAd, _amount);

    vm.prank(_signerAd);
    MAINNET_USDC.approve(address(l1Adapter), _amount);
    uint256 _deadline = block.timestamp + 1 days;

    uint256 _nonce = vm.getNonce(_signerAd);

    // Changing to `to` param to _user but we call it with _signerAd
    bytes memory _signature =
      _generateSignature(_user, _amount, _deadline, _nonce, _signerAd, _signerPk, address(l1Adapter));

    // Different address can execute the message
    vm.startPrank(_user);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidSignature.selector);
    l1Adapter.sendMessage(_signerAd, _signerAd, _amount, _signature, _deadline, _MIN_GAS_LIMIT);
    vm.stopPrank();
  }
}

contract Integration_Migration is IntegrationBase {
  address internal _circle = makeAddr('circle');
  uint32 internal _minGasLimitReceiveOnL2 = 1_000_000;
  uint32 internal _minGasLimitSetBurnAmount = 1_000_000;

  function setUp() public override {
    super.setUp();

    _mintSupplyOnL2(optimism, OP_ALIASED_L1_MESSENGER, _amount);

    vm.selectFork(mainnet);
    // Adapter needs to be minter to burn
    vm.prank(MAINNET_USDC.masterMinter());
    MAINNET_USDC.configureMinter(address(l1Adapter), 0);
  }

  /**
   * @notice Test the migration to native usdc flow
   */
  function test_migrationToNativeUSDC() public {
    vm.selectFork(mainnet);

    vm.prank(_owner);
    l1Adapter.migrateToNative(_circle, _circle, _minGasLimitReceiveOnL2, _minGasLimitSetBurnAmount);

    assertEq(uint256(l1Adapter.messengerStatus()), uint256(IL1OpUSDCBridgeAdapter.Status.Upgrading));
    assertEq(l1Adapter.burnCaller(), _circle);

    vm.selectFork(optimism);
    _relayL1ToL2Message(
      OP_ALIASED_L1_MESSENGER,
      address(l1Adapter),
      address(l2Adapter),
      _ZERO_VALUE,
      _minGasLimitReceiveOnL2,
      abi.encodeWithSignature('receiveMigrateToNative(address,uint32)', _circle, _minGasLimitSetBurnAmount)
    );

    uint256 _burnAmount = bridgedUSDC.totalSupply();

    assertEq(l2Adapter.isMessagingDisabled(), true);
    assertEq(l2Adapter.roleCaller(), _circle);

    vm.prank(_circle);
    l2Adapter.transferUSDCRoles(_circle);

    assertEq(bridgedUSDC.owner(), _circle);

    vm.selectFork(mainnet);
    _relayL2ToL1Message(
      address(l2Adapter),
      address(l1Adapter),
      _ZERO_VALUE,
      _minGasLimitSetBurnAmount,
      abi.encodeWithSignature('setBurnAmount(uint256)', _burnAmount)
    );

    assertEq(l1Adapter.burnAmount(), _burnAmount);
    assertEq(l1Adapter.USDC(), address(MAINNET_USDC));
    assertEq(uint256(l1Adapter.messengerStatus()), uint256(IL1OpUSDCBridgeAdapter.Status.Deprecated));

    vm.prank(_circle);
    l1Adapter.burnLockedUSDC();

    assertEq(MAINNET_USDC.balanceOf(address(l1Adapter)), 0);
    assertEq(l1Adapter.burnAmount(), 0);
    assertEq(l1Adapter.burnCaller(), address(0));
  }

  /**
   * @notice Test migration flow is some calls reverted cause of blacklisted funds
   */
  function test_migrationToNativeWithBlacklistedFunds() public {
    vm.selectFork(optimism);
    vm.prank(bridgedUSDC.blacklister());
    bridgedUSDC.blacklist(_user);
    uint256 _blacklistedAmount = _amount + 100;

    _mintSupplyOnL2(optimism, OP_ALIASED_L1_MESSENGER, _blacklistedAmount);

    assertEq(l2Adapter.blacklistedFunds(), _blacklistedAmount);

    vm.selectFork(mainnet);

    vm.prank(_owner);
    l1Adapter.migrateToNative(_circle, _circle, _minGasLimitReceiveOnL2, _minGasLimitSetBurnAmount);

    assertEq(uint256(l1Adapter.messengerStatus()), uint256(IL1OpUSDCBridgeAdapter.Status.Upgrading));
    assertEq(l1Adapter.burnCaller(), _circle);

    vm.selectFork(optimism);
    _relayL1ToL2Message(
      OP_ALIASED_L1_MESSENGER,
      address(l1Adapter),
      address(l2Adapter),
      _ZERO_VALUE,
      _minGasLimitReceiveOnL2,
      abi.encodeWithSignature('receiveMigrateToNative(address,uint32)', _circle, _minGasLimitSetBurnAmount)
    );

    uint256 _burnAmount = bridgedUSDC.totalSupply() + l2Adapter.blacklistedFunds();

    assertEq(l2Adapter.isMessagingDisabled(), true);
    assertEq(l2Adapter.roleCaller(), _circle);

    vm.prank(_circle);
    l2Adapter.transferUSDCRoles(_circle);

    assertEq(bridgedUSDC.owner(), _circle);

    vm.selectFork(mainnet);
    _relayL2ToL1Message(
      address(l2Adapter),
      address(l1Adapter),
      _ZERO_VALUE,
      _minGasLimitSetBurnAmount,
      abi.encodeWithSignature('setBurnAmount(uint256)', _burnAmount)
    );

    assertEq(l1Adapter.burnAmount(), _burnAmount);
    assertEq(l1Adapter.USDC(), address(MAINNET_USDC));
    assertEq(uint256(l1Adapter.messengerStatus()), uint256(IL1OpUSDCBridgeAdapter.Status.Deprecated));

    vm.prank(_circle);
    l1Adapter.burnLockedUSDC();

    assertEq(MAINNET_USDC.balanceOf(address(l1Adapter)), 0);
    assertEq(l1Adapter.burnAmount(), 0);
    assertEq(l1Adapter.burnCaller(), address(0));
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
    l1Adapter.stopMessaging(_MIN_GAS_LIMIT);

    assertEq(uint256(l1Adapter.messengerStatus()), uint256(IL1OpUSDCBridgeAdapter.Status.Paused));

    vm.selectFork(optimism);
    _relayL1ToL2Message(
      OP_ALIASED_L1_MESSENGER,
      address(l1Adapter),
      address(l2Adapter),
      _ZERO_VALUE,
      _MIN_GAS_LIMIT,
      abi.encodeWithSignature('receiveStopMessaging()')
    );

    assertEq(l2Adapter.isMessagingDisabled(), true);

    vm.selectFork(mainnet);

    vm.prank(_owner);
    l1Adapter.resumeMessaging(_MIN_GAS_LIMIT);

    assertEq(uint256(l1Adapter.messengerStatus()), uint256(IL1OpUSDCBridgeAdapter.Status.Active));

    vm.selectFork(optimism);

    _relayL1ToL2Message(
      OP_ALIASED_L1_MESSENGER,
      address(l1Adapter),
      address(l2Adapter),
      _ZERO_VALUE,
      _MIN_GAS_LIMIT,
      abi.encodeWithSignature('receiveResumeMessaging()')
    );

    assertEq(l2Adapter.isMessagingDisabled(), false);
  }
}
