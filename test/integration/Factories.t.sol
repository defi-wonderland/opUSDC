// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IntegrationBase} from './IntegrationBase.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';

import {IL1OpUSDCFactory} from 'interfaces/IL1OpUSDCFactory.sol';
import {IL2OpUSDCBridgeAdapter} from 'interfaces/IL2OpUSDCBridgeAdapter.sol';
import {IL2OpUSDCDeploy} from 'interfaces/IL2OpUSDCDeploy.sol';
import {IOpUSDCBridgeAdapter} from 'interfaces/IOpUSDCBridgeAdapter.sol';
import {IUSDC} from 'interfaces/external/IUSDC.sol';
import {USDC_IMPLEMENTATION_CREATION_CODE} from 'test/utils/USDCImplementationCreationCode.sol';

contract Integration_Factories is IntegrationBase {
  /**
   * @notice Check all the L1 and L2 contracts are properly deployed and initialized
   */
  function test_deployAllContracts() public {
    vm.selectFork(mainnet);
    vm.roll(block.number + 1);

    IL1OpUSDCFactory.L2Deployments memory _l2Deployments = l2Deployments;

    _l2Deployments.usdcInitTxs[0] = abi.encodeWithSignature('initializeV2(string)', 'Bridged USDC (Optimism)');

    // Deploy the contracts
    uint256 _deploymentsSaltCounter = l1Factory.deploymentsSaltCounter();
    vm.prank(_user);
    (address _l1Adapter, address _l2Factory, address _l2Adapter) =
      l1Factory.deploy(address(OPTIMISM_L1_MESSENGER), _owner, 'Optimism', _l2Deployments);

    // Check the adapter was properly deployed on L1
    assertEq(IOpUSDCBridgeAdapter(_l1Adapter).USDC(), address(MAINNET_USDC), '1');
    assertEq(IOpUSDCBridgeAdapter(_l1Adapter).MESSENGER(), address(OPTIMISM_L1_MESSENGER), '2');
    assertEq(IOpUSDCBridgeAdapter(_l1Adapter).LINKED_ADAPTER(), _l2Adapter, '3');
    assertEq(Ownable(_l1Adapter).owner(), _owner);

    bytes32 _salt = bytes32(l1Factory.deploymentsSaltCounter());

    // Get the L1 values needed to assert the proper deployments on L2
    string memory _usdcSymbol = l1Factory.USDC_SYMBOL();
    uint8 _usdcDecimals = MAINNET_USDC.decimals();
    string memory _usdcCurrency = MAINNET_USDC.currency();

    vm.selectFork(optimism);
    IL2OpUSDCDeploy.USDCInitializeData memory _usdcInitializeData = usdcInitializeData;
    _usdcInitializeData.tokenName = 'Bridged USDC (Optimism)';
    // Relay the L2 deployments message through the factory on L2
    _relayL2Deployments(OP_ALIASED_L1_MESSENGER, _salt, _l1Adapter, _usdcInitializeData, _l2Deployments);

    // Check the adapter was properly deployed on L2
    IUSDC _l2Usdc = IUSDC(IOpUSDCBridgeAdapter(_l2Adapter).USDC());
    assertEq(IOpUSDCBridgeAdapter(_l2Adapter).MESSENGER(), address(L2_MESSENGER), '4');
    assertEq(IOpUSDCBridgeAdapter(_l2Adapter).LINKED_ADAPTER(), _l1Adapter, '5');
    assertEq(Ownable(_l2Adapter).owner(), _owner, '6');

    // Check the L2 factory was deployed
    assertGt(_l2Factory.code.length, 0, '7');

    // Check the USDC was properly deployed on L2
    assertEq(_l2Usdc.name(), 'Bridged USDC (Optimism)', '8');
    assertEq(_l2Usdc.symbol(), _usdcSymbol, '9');
    assertEq(_l2Usdc.decimals(), _usdcDecimals, '10');
    assertEq(_l2Usdc.currency(), _usdcCurrency, '11');
    assertGt(_l2Usdc.implementation().code.length, 0, '12');

    // Check the USDC permissions and allowances were properly set
    assertEq(_l2Usdc.admin(), address(IL2OpUSDCBridgeAdapter(_l2Adapter).FALLBACK_PROXY_ADMIN()));
    assertEq(_l2Usdc.masterMinter(), _l2Adapter);
    assertEq(_l2Usdc.pauser(), _l2Adapter);
    assertEq(_l2Usdc.blacklister(), _l2Adapter);
    assertEq(_l2Usdc.isMinter(_l2Adapter), true);
    assertEq(_l2Usdc.minterAllowance(_l2Adapter), type(uint256).max);
  }

  /**
   * @notice Check the L1 and L2 contracts are deployed on different addresses on different triggered deployments
   */
  function test_deployOnDifferentAddresses() public {
    vm.selectFork(mainnet);
    vm.roll(block.number + 1);

    // Trigger another deployment
    (address _secondL1Adapter, address _secondL2Factory, address _secondL2Adapter) =
      l1Factory.deploy(address(OPTIMISM_L1_MESSENGER), _owner, 'Optimism', l2Deployments);
    bytes32 _secondSalt = bytes32(l1Factory.deploymentsSaltCounter());
    vm.stopPrank();

    vm.selectFork(optimism);
    IL2OpUSDCDeploy.USDCInitializeData memory _usdcInitializeData = usdcInitializeData;
    _usdcInitializeData.tokenName = 'Bridged USDC (Optimism)';
    // Relay the second triggered L2 deployments message
    _relayL2Deployments(OP_ALIASED_L1_MESSENGER, _secondSalt, _secondL1Adapter, _usdcInitializeData, l2Deployments);

    // Get the usdc proxy and implementation addresses
    IUSDC _secondL2Usdc = IUSDC(IOpUSDCBridgeAdapter(_secondL2Adapter).USDC());

    // Check the deployed addresses always differ
    assertTrue(_secondL1Adapter != address(l1Adapter));
    assertTrue(_secondL2Factory != address(l2Factory));
    assertTrue(_secondL2Adapter != address(l2Adapter));
    assertTrue(_secondL2Usdc != bridgedUSDC);
  }

  /**
   * @notice Check that deployments on OP and BASE succeeds, and the contracts addresses are different
   */
  function test_deployOnMultipleL2s() public {
    // Deploy L1 Adapter and trigger the contracts deployments on OP
    vm.selectFork(mainnet);
    vm.roll(block.number + 1);

    vm.startPrank(_owner);
    (address _opL1Adapter, address _opL2Factory, address _opL2Adapter) =
      l1Factory.deploy(address(OPTIMISM_L1_MESSENGER), _owner, 'Optimism', l2Deployments);
    bytes32 _opSalt = bytes32(l1Factory.deploymentsSaltCounter());
    vm.stopPrank();

    // Check the L1 adapter was deployed
    assertGt(_opL1Adapter.code.length, 0);

    // Relay the L2 deployments on OP
    vm.selectFork(optimism);
    IL2OpUSDCDeploy.USDCInitializeData memory _usdcInitializeData = usdcInitializeData;
    _usdcInitializeData.tokenName = 'Bridged USDC (Optimism)';
    _relayL2Deployments(OP_ALIASED_L1_MESSENGER, _opSalt, _opL1Adapter, _usdcInitializeData, l2Deployments);

    // Assert the contract were deployed to the expected addresses
    IUSDC _opL2Usdc = IUSDC(IOpUSDCBridgeAdapter(_opL2Adapter).USDC());
    assertGt(_opL2Factory.code.length, 0);
    assertGt(address(_opL2Usdc).code.length, 0);
    assertGt(_opL2Usdc.implementation().code.length, 0);
    assertGt(_opL2Adapter.code.length, 0);

    // Relay the L2 deployments on BASE
    vm.selectFork(base);
    // Deploy implementation on base
    address _usdcImplAddr;
    bytes memory _USDC_IMPLEMENTATION_CREATION_CODE = USDC_IMPLEMENTATION_CREATION_CODE;
    assembly {
      _usdcImplAddr :=
        create(0, add(_USDC_IMPLEMENTATION_CREATION_CODE, 0x20), mload(_USDC_IMPLEMENTATION_CREATION_CODE))
    }
    l2Deployments.usdcImplAddr = _usdcImplAddr;

    // Go back to mainnet to trigger the deployment from L1
    vm.selectFork(mainnet);

    vm.startPrank(_owner);
    // Deploy L1 Adapter and trigger the contracts deployments on BASE
    (address _baseL1Adapter, address _baseL2Factory, address _baseL2Adapter) =
      l1Factory.deploy(address(BASE_L1_MESSENGER), _owner, 'Base', l2Deployments);
    bytes32 _baseSalt = bytes32(l1Factory.deploymentsSaltCounter());
    vm.stopPrank();

    // Check the L1 adapter was deployed
    assertGt(_baseL1Adapter.code.length, 0);

    // Back to base to relay the L2 deployments
    vm.selectFork(base);
    _usdcInitializeData.tokenName = 'Bridged USDC (Base)';
    _relayL2Deployments(BASE_ALIASED_L1_MESSENGER, _baseSalt, _baseL1Adapter, _usdcInitializeData, l2Deployments);

    // Assert the contract were deployed to the expected addresses
    IUSDC _baseL2Usdc = IUSDC(IOpUSDCBridgeAdapter(_baseL2Adapter).USDC());
    assertGt(_baseL2Factory.code.length, 0);
    assertGt(address(_baseL2Usdc).code.length, 0);
    assertGt(_baseL2Usdc.implementation().code.length, 0);
    assertGt(_baseL2Adapter.code.length, 0);

    // Check the deployed addresses always differ (L1 adapters not checked since in case of being the same, it would
    // revert due to a colission)
    assertTrue(_opL1Adapter != _baseL1Adapter);
    assertTrue(_opL2Factory != _baseL2Factory);
    assertTrue(_opL2Adapter != _baseL2Adapter);
  }
}
