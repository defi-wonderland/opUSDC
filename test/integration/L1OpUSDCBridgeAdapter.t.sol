// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IntegrationBase} from './IntegrationBase.sol';
import {AddressAliasHelper} from 'test/utils/AddressAliasHelper.sol';

contract Integration_Bridging is IntegrationBase {
  /**
   * @notice Test the bridging process from L1 -> L2
   */
  function test_bridgeFromL1() public {
    vm.selectFork(mainnet);

    uint256 _amount = 1e18;
    uint32 _minGasLimit = 1_000_000;

    // Deal doesnt work with proxies
    vm.startPrank(MAINNET_USDC.masterMinter());
    MAINNET_USDC.configureMinter(MAINNET_USDC.masterMinter(), type(uint256).max);
    MAINNET_USDC.mint(_user, _amount);
    vm.stopPrank();

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
}
