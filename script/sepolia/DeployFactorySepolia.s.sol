// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {L1OpUSDCBridgeAdapter} from 'contracts/L1OpUSDCBridgeAdapter.sol';
import {L2OpUSDCBridgeAdapter} from 'contracts/L2OpUSDCBridgeAdapter.sol';
import {OpUSDCFactory} from 'contracts/OpUSDCFactory.sol';
import {USDC_IMPLEMENTATION_BYTECODE, USDC_PROXY_BYTECODE} from 'contracts/utils/USDCCreationCode.sol';
import {Script} from 'forge-std/Script.sol';
import {IOpUSDCFactory} from 'interfaces/IOpUSDCFactory.sol';
import {ICreateX} from 'interfaces/external/ICreateX.sol';
import {ICrossDomainMessenger} from 'interfaces/external/ICrossDomainMessenger.sol';

contract DeployFactorySepolia is Script {
  ICrossDomainMessenger public constant L1_CROSS_DOMAIN_MESSENGER =
    ICrossDomainMessenger(0x58Cc85b8D04EA49cC6DBd3CbFFd00B4B8D6cb3ef);
  address public constant L2_CROSS_DOMAIN_MESSENGER = 0x4200000000000000000000000000000000000007;
  address public constant L1_USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
  ICreateX public constant L1_CREATEX = ICreateX(0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed);
  address public constant L2_CREATEX = 0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed;
  uint32 public constant MIN_GAS_LIMIT_USDC_PROXY_DEPLOY = 1_000_000;
  uint32 public constant MIN_GAS_LIMIT_USDC_IMPLEMENTATION_DEPLOY = 7_000_000;
  uint32 public constant MIN_GAS_LIMIT_ADAPTER_DEPLOY = 3_000_000;
  uint32 public constant MIN_GAS_LIMIT_INITIALIZE_TXS = 200_000;

  address public deployer = vm.rememberKey(vm.envUint('SEPOLIA_DEPLOYER_PK'));

  function run() public {
    vm.startBroadcast(deployer);

    // Deploy OpUSDCFactory
    uint256 _salt = block.number + uint256(blockhash(block.number - 1));
    OpUSDCFactory factory = new OpUSDCFactory(L1_CROSS_DOMAIN_MESSENGER, L1_USDC, L1_CREATEX, L2_CREATEX, _salt);

    // Run the deploy function
    address _owner = vm.envAddress('OWNER_ADDRESS');
    uint256 _l2ChainId = vm.envUint('TESTNET_L2_CHAIN_ID');

    IOpUSDCFactory.DeployParams memory _params = IOpUSDCFactory.DeployParams({
      l2Messenger: L2_CROSS_DOMAIN_MESSENGER,
      l1OpUSDCBridgeAdapterCreationCode: type(L1OpUSDCBridgeAdapter).creationCode,
      l2OpUSDCBridgeAdapterCreationCode: type(L2OpUSDCBridgeAdapter).creationCode,
      usdcProxyCreationCode: USDC_PROXY_BYTECODE,
      usdcImplementationCreationCode: USDC_IMPLEMENTATION_BYTECODE,
      owner: _owner,
      minGasLimitUsdcProxyDeploy: MIN_GAS_LIMIT_USDC_PROXY_DEPLOY,
      minGasLimitUsdcImplementationDeploy: MIN_GAS_LIMIT_USDC_IMPLEMENTATION_DEPLOY,
      minGasLimitL2AdapterDeploy: MIN_GAS_LIMIT_ADAPTER_DEPLOY,
      minGasLimitInitializeTxs: MIN_GAS_LIMIT_INITIALIZE_TXS,
      l2ChainId: _l2ChainId
    });

    factory.deploy(_params);

    vm.stopBroadcast();
  }
}
