// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/Test.sol';
import {IL1OpUSDCFactory} from 'interfaces/IL1OpUSDCFactory.sol';
import {USDCInitTxs} from 'src/contracts/utils/USDCInitTxs.sol';

contract DeployOptimism is Script {
  address public constant L1_MESSENGER = 0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1;
  uint32 public constant MIN_GAS_LIMIT_DEPLOY = 9_000_000;
  IL1OpUSDCFactory public immutable L1_FACTORY = IL1OpUSDCFactory(vm.envAddress('L1_FACTORY_MAINNET'));
  address public immutable USDC_OPTIMISM_IMPLEMENTATION = vm.envAddress('USDC_OPTIMISM_IMPLEMENTATION');
  address public owner = vm.rememberKey(vm.envUint('MAINNET_PK'));

  function run() public {
    vm.startBroadcast(owner);
    bytes[] memory _usdcInitTxs = new bytes[](3);
    _usdcInitTxs[0] = USDCInitTxs.INITIALIZEV2;
    _usdcInitTxs[1] = USDCInitTxs.INITIALIZEV2_1;
    _usdcInitTxs[2] = USDCInitTxs.INITIALIZEV2_2;

    IL1OpUSDCFactory.L2Deployments memory _l2Deployments = IL1OpUSDCFactory.L2Deployments({
      l2AdapterOwner: owner,
      usdcImplAddr: USDC_OPTIMISM_IMPLEMENTATION,
      usdcInitTxs: _usdcInitTxs,
      minGasLimitDeploy: MIN_GAS_LIMIT_DEPLOY
    });

    // Deploy the L2 contracts
    (address _l1Adapter, address _l2Factory, address _l2Adapter) =
      L1_FACTORY.deploy(L1_MESSENGER, owner, _l2Deployments);
    vm.stopBroadcast();

    /// NOTE: Hardcode the `L1_ADAPTER_OP` and `L2_ADAPTER_OP` addresses inside the `.env` file
    console.log('L1 Adapter:', _l1Adapter);
    console.log('L2 Factory:', _l2Factory);
    console.log('L2 Adapter:', _l2Adapter);
  }
}
