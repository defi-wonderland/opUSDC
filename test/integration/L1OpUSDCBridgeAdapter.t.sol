// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IntegrationBase} from './IntegrationBase.sol';
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
      abi.encodeWithSignature('receiveMessage(address,address,uint256)', _user, _user, _amount)
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
      abi.encodeWithSignature('receiveMessage(address,address,uint256)', _l2Target, _user, _amount)
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
    bytes memory _signature = _generateSignature(
      _signerAd, _amount, _deadline, _MIN_GAS_LIMIT, _USER_NONCE, _signerAd, _signerPk, address(l1Adapter)
    );

    // Different address can execute the message
    vm.prank(_user);
    l1Adapter.sendMessage(_signerAd, _signerAd, _amount, _signature, _USER_NONCE, _deadline, _MIN_GAS_LIMIT);

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
      abi.encodeWithSignature('receiveMessage(address,address,uint256)', _signerAd, _signerAd, _amount)
    );

    assertEq(bridgedUSDC.balanceOf(_signerAd), _userBalanceBefore + _amount);
    assertEq(bridgedUSDC.balanceOf(_user), 0);
  }

  /**
   * @notice Test signature message reverts with a signature that was canceled by disabling the nonce
   */
  function test_bridgeFromL1WithCanceledSignature() public {
    (address _signerAd, uint256 _signerPk) = makeAddrAndKey('signer');
    vm.selectFork(mainnet);

    // We need to do this instead of `deal` because deal doesnt change `totalSupply` state
    vm.prank(MAINNET_USDC.masterMinter());
    MAINNET_USDC.mint(_signerAd, _amount);

    // Give allowance to the adapter
    vm.prank(_signerAd);
    MAINNET_USDC.approve(address(l1Adapter), _amount);

    // Changing to `to` param to _user but we call it with _signerAd
    uint256 _deadline = block.timestamp + 1 days;
    bytes memory _signature = _generateSignature(
      _user, _amount, _deadline, _MIN_GAS_LIMIT, _USER_NONCE, _signerAd, _signerPk, address(l1Adapter)
    );

    // Cancel the signature
    vm.prank(_signerAd);
    l1Adapter.cancelSignature(_USER_NONCE);

    // Different address will execute the message, and it should revert because the nonce is disabled
    vm.startPrank(_user);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidNonce.selector);
    l1Adapter.sendMessage(_signerAd, _signerAd, _amount, _signature, _USER_NONCE, _deadline, _MIN_GAS_LIMIT);
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

    // Give allowance to the adapter
    vm.prank(_signerAd);
    MAINNET_USDC.approve(address(l1Adapter), _amount);

    // Changing to `to` param to _user but we call it with _signerAd
    uint256 _deadline = block.timestamp + 1 days;
    bytes memory _signature = _generateSignature(
      _user, _amount, _deadline, _MIN_GAS_LIMIT, _USER_NONCE, _signerAd, _signerPk, address(l1Adapter)
    );

    // Different address can execute the message
    vm.startPrank(_user);
    vm.expectRevert(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidSignature.selector);
    l1Adapter.sendMessage(_signerAd, _signerAd, _amount, _signature, _USER_NONCE, _deadline, _MIN_GAS_LIMIT);
    vm.stopPrank();
  }

  function test_recoverBlacklistedFundsAfterMigration() public {
    // Blacklist `_user` on L2
    vm.selectFork(optimism);
    vm.prank(bridgedUSDC.blacklister());
    bridgedUSDC.blacklist(_user);

    // Create address for the spender
    address _spender = makeAddr('spender');

    // Select mainnet fork
    vm.selectFork(mainnet);

    // Mint mainnet USDC to the spender
    vm.prank(MAINNET_USDC.masterMinter());
    MAINNET_USDC.mint(_spender, _amount);

    // Approve the L1 adapter to spend the USDC
    vm.prank(_spender);
    MAINNET_USDC.approve(address(l1Adapter), _amount);

    // Spender send USDC to the User on L2
    vm.prank(_spender);
    l1Adapter.sendMessage(_user, _amount, _MIN_GAS_LIMIT);

    // Check that the USDC are correctly sent to the user
    assertEq(MAINNET_USDC.balanceOf(_spender), 0);

    // Relay the message to L2
    vm.selectFork(optimism);
    _relayL1ToL2Message(
      OP_ALIASED_L1_MESSENGER,
      address(l1Adapter),
      address(l2Adapter),
      _ZERO_VALUE,
      1_000_000,
      abi.encodeWithSignature('receiveMessage(address,address,uint256)', _user, _spender, _amount)
    );

    // Check that the blacklisted funds are correctly computed
    assertEq(l2Adapter.blacklistedFundsDetails(_spender, _user), _amount);

    // Migration to native USDC
    {
      address _roleCaller = makeAddr('circle');
      address _burnCaller = makeAddr('circle');
      uint32 _minGasLimitReceiveOnL2 = 1_000_000;
      uint32 _minGasLimitSetBurnAmount = 1_000_000;

      vm.selectFork(mainnet);
      vm.prank(_owner);
      l1Adapter.migrateToNative(_roleCaller, _burnCaller, _MIN_GAS_LIMIT, _MIN_GAS_LIMIT);

      //This is necessary to set the messenger status to deprecated on L1
      vm.selectFork(optimism);
      _relayL1ToL2Message(
        OP_ALIASED_L1_MESSENGER,
        address(l1Adapter),
        address(l2Adapter),
        _ZERO_VALUE,
        _minGasLimitReceiveOnL2,
        abi.encodeWithSignature('receiveMigrateToNative(address,uint32)', _roleCaller, _minGasLimitSetBurnAmount)
      );

      assertEq(uint256(l2Adapter.messengerStatus()), uint256(IOpUSDCBridgeAdapter.Status.Deprecated));

      uint256 _burnAmount = bridgedUSDC.totalSupply();

      //This is necessary to set the messenger status to deprecated on L1
      vm.selectFork(mainnet);
      _relayL2ToL1Message(
        address(l2Adapter),
        address(l1Adapter),
        _ZERO_VALUE,
        _minGasLimitSetBurnAmount,
        abi.encodeWithSignature('setBurnAmount(uint256)', _burnAmount)
      );

      assertEq(uint256(l1Adapter.messengerStatus()), uint256(IOpUSDCBridgeAdapter.Status.Deprecated));
    }

    // Check that any user can call the withdrawBlacklistedFunds function
    address _anyUser = makeAddr('anyUser');
    vm.selectFork(optimism);
    vm.prank(_anyUser);
    l2Adapter.withdrawBlacklistedFunds(_spender, _user);

    // Check that the blacklisted funds are correctly removed
    assertEq(l2Adapter.blacklistedFundsDetails(_spender, _user), 0);

    // Check that funds are returned to the spender if is not blacklisted
    vm.selectFork(mainnet);
    assertEq(MAINNET_USDC.isBlacklisted(_spender), false);
    _relayL2ToL1Message(
      address(l2Adapter),
      address(l1Adapter),
      _ZERO_VALUE,
      _MIN_GAS_LIMIT,
      abi.encodeWithSignature('receiveWithdrawBlacklistedFundsPostMigration(address,uint256)', _spender, _amount)
    );

    // Check that the funds are correctly returned to the spender
    assertEq(MAINNET_USDC.balanceOf(_spender), _amount);
  }
}

contract Integration_Migration is IntegrationBase {
  address internal _circle = makeAddr('circle');
  uint32 internal _minGasLimitReceiveOnL2 = 1_000_000;
  uint32 internal _minGasLimitSetBurnAmount = 1_000_000;

  function setUp() public override {
    super.setUp();

    vm.selectFork(mainnet);
    // Adapter needs to be minter to burn
    vm.prank(MAINNET_USDC.masterMinter());
    MAINNET_USDC.configureMinter(address(l1Adapter), 0);
  }

  /**
   * @notice Test the migration to native usdc flow
   */
  function test_migrationToNativeUSDC() public {
    _mintSupplyOnL2(optimism, OP_ALIASED_L1_MESSENGER, _amount);

    vm.selectFork(mainnet);

    vm.prank(_owner);
    l1Adapter.migrateToNative(_circle, _circle, _minGasLimitReceiveOnL2, _minGasLimitSetBurnAmount);

    assertEq(uint256(l1Adapter.messengerStatus()), uint256(IOpUSDCBridgeAdapter.Status.Upgrading));
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

    assertEq(uint256(l2Adapter.messengerStatus()), uint256(IOpUSDCBridgeAdapter.Status.Deprecated));
    assertEq(l2Adapter.roleCaller(), _circle);
    assertEq(bridgedUSDC.isMinter(address(l2Adapter)), false);

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
    assertEq(uint256(l1Adapter.messengerStatus()), uint256(IOpUSDCBridgeAdapter.Status.Deprecated));

    vm.prank(_circle);
    l1Adapter.burnLockedUSDC();

    assertEq(MAINNET_USDC.balanceOf(address(l1Adapter)), 0);
    assertEq(l1Adapter.burnAmount(), 0);
    assertEq(l1Adapter.burnCaller(), address(0));
  }

  /**
   * @notice Test the migration to native usdc flow with zero balance on L1
   * @dev This is a very edge case and will only happen if the chain operator adds a second minter on L2
   *      So now this adapter doesnt have the full backing supply locked in this contract
   */
  function test_migrationToNativeUSDCWithZeroBalanceOnL1() public {
    vm.selectFork(optimism);
    vm.prank(bridgedUSDC.masterMinter());
    bridgedUSDC.configureMinter(_owner, type(uint256).max);
    vm.prank(_owner);
    bridgedUSDC.mint(_owner, _amount);

    vm.selectFork(mainnet);

    vm.prank(_owner);
    l1Adapter.migrateToNative(_circle, _circle, _minGasLimitReceiveOnL2, _minGasLimitSetBurnAmount);

    assertEq(uint256(l1Adapter.messengerStatus()), uint256(IOpUSDCBridgeAdapter.Status.Upgrading));
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

    assertEq(uint256(l2Adapter.messengerStatus()), uint256(IOpUSDCBridgeAdapter.Status.Deprecated));
    assertEq(l2Adapter.roleCaller(), _circle);
    assertEq(bridgedUSDC.isMinter(address(l2Adapter)), false);

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
    assertEq(uint256(l1Adapter.messengerStatus()), uint256(IOpUSDCBridgeAdapter.Status.Deprecated));

    vm.prank(_circle);
    l1Adapter.burnLockedUSDC();

    assertEq(MAINNET_USDC.balanceOf(address(l1Adapter)), 0);
    assertEq(l1Adapter.burnAmount(), 0);
    assertEq(l1Adapter.burnCaller(), address(0));
  }

  /**
   * @notice Test relay message after migration to native usdc
   */
  function test_relayMessageAfterMigrationToNativeUSDC() public {
    vm.selectFork(mainnet);

    uint256 _supply = 1_000_000;

    vm.startPrank(MAINNET_USDC.masterMinter());
    MAINNET_USDC.configureMinter(MAINNET_USDC.masterMinter(), _supply);
    MAINNET_USDC.mint(_user, _supply);
    vm.stopPrank();

    vm.startPrank(_user);
    MAINNET_USDC.approve(address(l1Adapter), _supply);
    l1Adapter.sendMessage(_user, _supply, _MIN_GAS_LIMIT);
    vm.stopPrank();

    vm.prank(_owner);
    l1Adapter.migrateToNative(_circle, _circle, _minGasLimitReceiveOnL2, _minGasLimitSetBurnAmount);

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
    assertEq(uint256(l2Adapter.messengerStatus()), uint256(IOpUSDCBridgeAdapter.Status.Deprecated));

    vm.selectFork(mainnet);
    _relayL2ToL1Message(
      address(l2Adapter),
      address(l1Adapter),
      _ZERO_VALUE,
      _minGasLimitSetBurnAmount,
      abi.encodeWithSignature('setBurnAmount(uint256)', _burnAmount)
    );

    assertEq(uint256(l1Adapter.messengerStatus()), uint256(IOpUSDCBridgeAdapter.Status.Deprecated));

    vm.selectFork(optimism);

    vm.expectCall(
      0x4200000000000000000000000000000000000007,
      abi.encodeWithSignature(
        'sendMessage(address,bytes,uint32)',
        address(l1Adapter),
        abi.encodeWithSignature('receiveMessage(address,address,uint256)', _user, _user, _amount),
        150_000
      )
    );

    uint256 _totalSupplyBefore = bridgedUSDC.totalSupply();

    _relayL1ToL2Message(
      OP_ALIASED_L1_MESSENGER,
      address(l1Adapter),
      address(l2Adapter),
      _ZERO_VALUE,
      1_000_000,
      abi.encodeWithSignature('receiveMessage(address,address,uint256)', _user, _user, _amount)
    );

    assertEq(bridgedUSDC.totalSupply(), _totalSupplyBefore);
  }
}

contract Integration_Integration_PermissionedFlows is IntegrationBase {
  /**
   * @notice Test that the messaging is stopped and resumed correctly from L1 on
   * both layers
   */
  function test_stopAndResumeMessaging() public {
    vm.selectFork(mainnet);

    assertEq(uint256(l1Adapter.messengerStatus()), uint256(IOpUSDCBridgeAdapter.Status.Active));

    vm.prank(_owner);
    l1Adapter.stopMessaging(_MIN_GAS_LIMIT);

    assertEq(uint256(l1Adapter.messengerStatus()), uint256(IOpUSDCBridgeAdapter.Status.Paused));

    vm.selectFork(optimism);
    _relayL1ToL2Message(
      OP_ALIASED_L1_MESSENGER,
      address(l1Adapter),
      address(l2Adapter),
      _ZERO_VALUE,
      _MIN_GAS_LIMIT,
      abi.encodeWithSignature('receiveStopMessaging()')
    );

    assertEq(uint256(l2Adapter.messengerStatus()), uint256(IOpUSDCBridgeAdapter.Status.Paused));

    vm.selectFork(mainnet);

    vm.prank(_owner);
    l1Adapter.resumeMessaging(_MIN_GAS_LIMIT);

    assertEq(uint256(l1Adapter.messengerStatus()), uint256(IOpUSDCBridgeAdapter.Status.Active));

    vm.selectFork(optimism);

    _relayL1ToL2Message(
      OP_ALIASED_L1_MESSENGER,
      address(l1Adapter),
      address(l2Adapter),
      _ZERO_VALUE,
      _MIN_GAS_LIMIT,
      abi.encodeWithSignature('receiveResumeMessaging()')
    );

    assertEq(uint256(l2Adapter.messengerStatus()), uint256(IOpUSDCBridgeAdapter.Status.Active));
  }

  /**
   * @notice Test that the user can withdraw the blacklisted funds if they get unblacklisted
   */
  function test_userCanWithdrawBlacklistedFunds() public {
    vm.selectFork(mainnet);
    _mintSupplyOnL2(optimism, OP_ALIASED_L1_MESSENGER, _amount);

    vm.selectFork(optimism);
    vm.startPrank(_user);
    bridgedUSDC.approve(address(l2Adapter), _amount);
    l2Adapter.sendMessage(_user, _amount, _MIN_GAS_LIMIT);
    vm.stopPrank();
    assertEq(bridgedUSDC.balanceOf(_user), 0);

    vm.selectFork(mainnet);

    vm.prank(MAINNET_USDC.blacklister());
    MAINNET_USDC.blacklist(_user);
    _relayL2ToL1Message(
      address(l2Adapter),
      address(l1Adapter),
      _ZERO_VALUE,
      _MIN_GAS_LIMIT,
      abi.encodeWithSignature('receiveMessage(address,address,uint256)', _user, _user, _amount)
    );

    assertEq(MAINNET_USDC.balanceOf(_user), 0);

    vm.prank(MAINNET_USDC.blacklister());
    MAINNET_USDC.unBlacklist(_user);

    vm.prank(_user);
    l1Adapter.withdrawBlacklistedFunds(_user, _user);

    assertEq(MAINNET_USDC.balanceOf(_user), _amount);
    assertEq(l1Adapter.blacklistedFundsDetails(_user, _user), 0);
  }
}
