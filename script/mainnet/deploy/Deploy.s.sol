// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/Test.sol';
import {IL1OpUSDCFactory} from 'interfaces/IL1OpUSDCFactory.sol';
import {IUSDC} from 'interfaces/external/IUSDC.sol';
import {USDCInitTxs} from 'src/contracts/utils/USDCInitTxs.sol';

contract Deploy is Script {
  uint32 public constant MIN_GAS_LIMIT_DEPLOY = 9_000_000;
  IL1OpUSDCFactory public immutable L1_FACTORY = IL1OpUSDCFactory(vm.envAddress('L1_FACTORY_MAINNET'));
  address public immutable BRIDGED_USDC_IMPLEMENTATION = vm.envAddress('BRIDGED_USDC_IMPLEMENTATION');
  address public immutable L1_MESSENGER = vm.envAddress('L1_MESSENGER');
  string public chainName = vm.envString('CHAIN_NAME');
  address public owner = vm.rememberKey(vm.envUint('MAINNET_PK'));

  function run() public {
    vm.createSelectFork(vm.rpcUrl(vm.envString('MAINNET_RPC')));
    vm.startBroadcast(owner);

    // NOTE: We have these hardcoded to default values, if used in product you will need to change them

    bytes[] memory _usdcInitTxs = new bytes[](3);
    string memory _name = string.concat('Bridged ', ' ', '(', chainName, ')');

    _usdcInitTxs[0] = abi.encodeCall(IUSDC.initializeV2, (_name));
    _usdcInitTxs[1] = USDCInitTxs.INITIALIZEV2_1;
    _usdcInitTxs[2] = USDCInitTxs.INITIALIZEV2_2;

    // Sanity check to ensure the caller of this script changed this value to the proper naming
    assert(keccak256(_usdcInitTxs[0]) != keccak256(USDCInitTxs.INITIALIZEV2));

    IL1OpUSDCFactory.L2Deployments memory _l2Deployments = IL1OpUSDCFactory.L2Deployments({
      l2AdapterOwner: owner,
      usdcImplAddr: BRIDGED_USDC_IMPLEMENTATION,
      usdcInitTxs: _usdcInitTxs,
      minGasLimitDeploy: MIN_GAS_LIMIT_DEPLOY
    });

    // Deploy the L2 contracts
    (address _l1Adapter, address _l2Factory, address _l2Adapter) =
      L1_FACTORY.deploy(L1_MESSENGER, owner, chainName, _l2Deployments);
    vm.stopBroadcast();

    /// NOTE: Hardcode the `L1_ADAPTER_BASE` and `L2_ADAPTER_BASE` addresses inside the `.env` file
    console.log('L1 Adapter:', _l1Adapter);
    console.log('L2 Factory:', _l2Factory);
    console.log('L2 Adapter:', _l2Adapter);
  }
}
