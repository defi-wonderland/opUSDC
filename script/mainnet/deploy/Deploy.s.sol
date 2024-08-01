// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/Test.sol';
import {IL1OpUSDCFactory} from 'interfaces/IL1OpUSDCFactory.sol';
import {USDCInitTxs} from 'src/contracts/utils/USDCInitTxs.sol';

contract Deploy is Script {
  uint32 public constant MIN_GAS_LIMIT_DEPLOY = 9_000_000;
  IL1OpUSDCFactory public immutable L1_FACTORY = IL1OpUSDCFactory(vm.envAddress('L1_FACTORY_MAINNET'));
  address public immutable BRIDGED_USDC_IMPLEMENTATION = vm.envAddress('BRIDGED_USDC_IMPLEMENTATION');
  address public immutable L1_MESSENGER = vm.envAddress('CUSTOM_L1_MESSENGER');
  string public CHAIN_NAME = vm.envString('CHAIN_NAME');
  address public owner = vm.rememberKey(vm.envUint('MAINNET_PK'));

  function run() public {
    vm.createSelectFork(vm.rpcUrl(vm.envString('MAINNET_RPC')));
    vm.startBroadcast(owner);

    // NOTE: We have these hardcoded to default values, if used in product you will need to change them
    bytes[] memory _usdcInitTxs = new bytes[](3);
    _usdcInitTxs[0] = USDCInitTxs.INITIALIZEV2;
    _usdcInitTxs[1] = USDCInitTxs.INITIALIZEV2_1;
    _usdcInitTxs[2] = USDCInitTxs.INITIALIZEV2_2;

    IL1OpUSDCFactory.L2Deployments memory _l2Deployments = IL1OpUSDCFactory.L2Deployments({
      l2AdapterOwner: owner,
      usdcImplAddr: BRIDGED_USDC_IMPLEMENTATION,
      usdcInitTxs: _usdcInitTxs,
      minGasLimitDeploy: MIN_GAS_LIMIT_DEPLOY
    });

    // Deploy the L2 contracts
    (address _l1Adapter, address _l2Factory, address _l2Adapter) =
      L1_FACTORY.deploy(L1_MESSENGER, owner, CHAIN_NAME, _l2Deployments);
    vm.stopBroadcast();

    /// NOTE: Hardcode the `L1_ADAPTER_BASE` and `L2_ADAPTER_BASE` addresses inside the `.env` file
    console.log('L1 Adapter:', _l1Adapter);
    console.log('L2 Factory:', _l2Factory);
    console.log('L2 Adapter:', _l2Adapter);
  }
}
