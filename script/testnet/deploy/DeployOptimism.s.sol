// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/Test.sol';
import {IL1OpUSDCFactory} from 'interfaces/IL1OpUSDCFactory.sol';
import {USDCInitTxs} from 'src/contracts/utils/USDCInitTxs.sol';

contract DeployOptimism is Script {
  address public constant L1_MESSENGER = 0x58Cc85b8D04EA49cC6DBd3CbFFd00B4B8D6cb3ef;
  uint32 public constant MIN_GAS_LIMIT_DEPLOY = 9_000_000;
  string public constant CHAIN_NAME = 'Optimism Sepolia';
  IL1OpUSDCFactory public immutable L1_FACTORY = IL1OpUSDCFactory(vm.envAddress('L1_FACTORY_SEPOLIA'));
  address public immutable USDC_OPTIMISM_SEPOLIA_IMPLEMENTATION = vm.envAddress('USDC_OPTIMISM_SEPOLIA_IMPLEMENTATION');

  address public owner = vm.rememberKey(vm.envUint('SEPOLIA_PK'));

  function run() public {
    vm.startBroadcast(owner);
    bytes[] memory _usdcInitTxs = new bytes[](3);
    _usdcInitTxs[0] = USDCInitTxs.INITIALIZEV2;
    _usdcInitTxs[1] = USDCInitTxs.INITIALIZEV2_1;
    _usdcInitTxs[2] = USDCInitTxs.INITIALIZEV2_2;

    IL1OpUSDCFactory.L2Deployments memory _l2Deployments = IL1OpUSDCFactory.L2Deployments({
      l2AdapterOwner: owner,
      usdcImplAddr: USDC_OPTIMISM_SEPOLIA_IMPLEMENTATION,
      usdcInitTxs: _usdcInitTxs,
      minGasLimitDeploy: MIN_GAS_LIMIT_DEPLOY
    });

    // Deploy the L2 contracts
    (address _l1Adapter, address _l2Factory, address _l2Adapter) =
      L1_FACTORY.deploy(L1_MESSENGER, owner, CHAIN_NAME, _l2Deployments);
    vm.stopBroadcast();

    /// NOTE: Hardcode the `L1_ADAPTER_OP_SEPOLIA` and `L2_ADAPTER_OP_SEPOLIA` addresses inside the `.env` file
    console.log('L1 Adapter:', _l1Adapter);
    console.log('L2 Factory:', _l2Factory);
    console.log('L2 Adapter:', _l2Adapter);
  }
}
