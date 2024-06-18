// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IntegrationBase} from './IntegrationBase.sol';
import {IOpUSDCBridgeAdapter} from 'interfaces/IOpUSDCBridgeAdapter.sol';
import {AddressAliasHelper} from 'test/utils/AddressAliasHelper.sol';

contract Integration_Bridging is IntegrationBase {
  /**
   * @notice Test the bridging process from L1 -> L2
   */
  function test_bridgeFromL1() public {
    vm.selectFork(mainnet);

    uint256 _amount = 1e18;
    uint32 _minGasLimit = 1_000_000;

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

    uint256 _amount = 1e18;
    uint32 _minGasLimit = 1_000_000;
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

    uint256 _amount = 1e18;
    uint32 _minGasLimit = 1_000_000;

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

    uint256 _amount = 1e18;
    uint32 _minGasLimit = 1_000_000;

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
