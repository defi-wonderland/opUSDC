// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {FactoryDeploy} from '../FactoryDeploy.sol';
import {L1OpUSDCBridgeAdapter} from 'contracts/L1OpUSDCBridgeAdapter.sol';
import {L2OpUSDCBridgeAdapter} from 'contracts/L2OpUSDCBridgeAdapter.sol';
import {USDC_IMPLEMENTATION_BYTECODE, USDC_PROXY_BYTECODE} from 'contracts/utils/USDCCreationCode.sol';
import {IOpUSDCFactory} from 'interfaces/IOpUSDCFactory.sol';
import {ICrossDomainMessenger} from 'interfaces/external/ICrossDomainMessenger.sol';

contract FactoryDeployMainnet is FactoryDeploy {
  ICrossDomainMessenger public constant L1_CROSS_DOMAIN_MESSENGER =
    ICrossDomainMessenger(0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1);
  address public constant L2_CROSS_DOMAIN_MESSENGER = 0x4200000000000000000000000000000000000007;
  address public constant L1_USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
  address public constant CREATEX = 0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed;
  uint32 public constant MIN_GAS_LIMIT_USDC_IMPLEMENTATION_DEPLOY = 6_000_000;
  uint32 public constant MIN_GAS_LIMIT_USDC_PROXY_DEPLOY = 1_000_000;
  uint32 public constant MIN_GAS_LIMIT_L2_ADAPTER_DEPLOY = 2_000_000;
  uint32 public constant MIN_GAS_LIMIT_INITIALIZE_TXS = 200_000;

  address public deployer = vm.rememberKey(vm.envUint('MAINNET_DEPLOYER_PK'));

  function run() public {
    // Define the factory constructor args and deploy params struct
    uint256 _salt = block.number + uint256(blockhash(block.number));
    address _owner = vm.envAddress('OWNER_ADDRESS');
    uint256 _l2ChainId = vm.envUint('L2_CHAIN_ID');
    IOpUSDCFactory.DeployParams memory _params = IOpUSDCFactory.DeployParams({
      l1Messenger: L1_CROSS_DOMAIN_MESSENGER,
      l2Messenger: L2_CROSS_DOMAIN_MESSENGER,
      l1AdapterCreationCode: type(L1OpUSDCBridgeAdapter).creationCode,
      l2AdapterCreationCode: type(L2OpUSDCBridgeAdapter).creationCode,
      usdcProxyCreationCode: USDC_PROXY_BYTECODE,
      usdcImplementationCreationCode: USDC_IMPLEMENTATION_BYTECODE,
      owner: _owner,
      minGasLimitUsdcImplementationDeploy: MIN_GAS_LIMIT_USDC_IMPLEMENTATION_DEPLOY,
      minGasLimitUsdcProxyDeploy: MIN_GAS_LIMIT_USDC_PROXY_DEPLOY,
      minGasLimitL2AdapterDeploy: MIN_GAS_LIMIT_L2_ADAPTER_DEPLOY,
      minGasLimitInitTxs: MIN_GAS_LIMIT_INITIALIZE_TXS,
      l2ChainId: _l2ChainId
    });

    // Deploy the factory and run the deploy function
    _factoryDeploy(deployer, L1_USDC, CREATEX, _salt, _params);
  }
}