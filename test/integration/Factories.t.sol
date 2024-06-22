// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IntegrationBase} from './IntegrationBase.sol';

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {L1OpUSDCFactory} from 'contracts/L1OpUSDCFactory.sol';
import {StdStorage, stdStorage} from 'forge-std/StdStorage.sol';
import {IL1OpUSDCBridgeAdapter} from 'interfaces/IL1OpUSDCBridgeAdapter.sol';

import {IL2OpUSDCBridgeAdapter} from 'interfaces/IL2OpUSDCBridgeAdapter.sol';
import {IOpUSDCBridgeAdapter} from 'interfaces/IOpUSDCBridgeAdapter.sol';
import {IUSDC} from 'interfaces/external/IUSDC.sol';

contract Integration_Factories is IntegrationBase {
  function test_deployAllContracts() public {
    vm.selectFork(mainnet);

    // Deploy the contracts
    (address _l1Adapter, address _l2Factory, address _l2Adapter) =
      factory.deploy(address(OPTIMISM_L1_MESSENGER), _owner, l2Deployments);

    // Check the adapter was properly deployed on L1
    assertEq(IOpUSDCBridgeAdapter(_l1Adapter).USDC(), address(MAINNET_USDC), 'a');
    assertEq(IOpUSDCBridgeAdapter(_l1Adapter).MESSENGER(), address(OPTIMISM_L1_MESSENGER), 'b');
    assertEq(IOpUSDCBridgeAdapter(_l1Adapter).LINKED_ADAPTER(), _l2Adapter, 'c');
    assertEq(Ownable(_l1Adapter).owner(), _owner, 'd');

    bytes32 _salt = bytes32(factory.deploymentsSaltCounter());

    vm.selectFork(optimism);
    // Relay the L2 deployments message through the factory on L2
    _relayL2Deployments(_salt, _l1Adapter, usdcInitializeData, l2Deployments);

    // Check the adapter was properly deployed on L2
    IUSDC _l2Usdc = IUSDC(IOpUSDCBridgeAdapter(_l2Adapter).USDC());
    assertEq(IOpUSDCBridgeAdapter(_l2Adapter).MESSENGER(), address(L2_MESSENGER), '2');
    assertEq(IOpUSDCBridgeAdapter(_l2Adapter).LINKED_ADAPTER(), _l1Adapter, '3');
    assertEq(Ownable(_l2Adapter).owner(), _owner, '4');

    // TODO: check factory?

    // Check the USDC was properly deployed on L2
    assertEq(_l2Usdc.name(), 'Bridged USDC', '5');
    assertEq(_l2Usdc.symbol(), 'USDC.e', '6');
    assertEq(_l2Usdc.decimals(), 6, '7');
    assertEq(_l2Usdc.currency(), 'USD', '8');
    assertGt(_l2Usdc.implementation().code.length, 0, '9');

    // Check the USDC was properly initialized
    assertEq(_l2Usdc.admin(), address(IL2OpUSDCBridgeAdapter(_l2Adapter).FALLBACK_PROXY_ADMIN()), '10');
    assertEq(_l2Usdc.masterMinter(), _l2Adapter, '11');
    assertEq(_l2Usdc.pauser(), _l2Adapter, '12');
    assertEq(_l2Usdc.blacklister(), _l2Adapter, '13');
    assertEq(_l2Usdc.isMinter(_l2Adapter), true, '14');
    assertEq(_l2Usdc.minterAllowance(_l2Adapter), type(uint256).max, '15');
  }
}
