// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {FactoryDeploy} from '../FactoryDeploy.sol';
import {L1OpUSDCBridgeAdapter} from 'contracts/L1OpUSDCBridgeAdapter.sol';
import {L2OpUSDCBridgeAdapter} from 'contracts/L2OpUSDCBridgeAdapter.sol';
import {USDC_IMPLEMENTATION_BYTECODE, USDC_PROXY_BYTECODE} from 'contracts/utils/USDCCreationCode.sol';
import {IL1OpUSDCFactory} from 'interfaces/IL1OpUSDCFactory.sol';
import {ICrossDomainMessenger} from 'interfaces/external/ICrossDomainMessenger.sol';
import {IOptimismPortal} from 'interfaces/external/IOptimismPortal.sol';

contract FactoryDeployMainnet is FactoryDeploy {
  ICrossDomainMessenger public constant L1_CROSS_DOMAIN_MESSENGER =
    ICrossDomainMessenger(0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1);
  IOptimismPortal public constant PORTAL = IOptimismPortal(0xbEb5Fc579115071764c7423A4f12eDde41f106Ed);
  address public constant L2_CROSS_DOMAIN_MESSENGER = 0x4200000000000000000000000000000000000007;
  address public constant L1_USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
  address public constant CREATEX = 0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed;
  uint32 public constant MIN_GAS_LIMIT_USDC_IMPLEMENTATION_DEPLOY = 6_000_000;
  uint32 public constant MIN_GAS_LIMIT_USDC_PROXY_DEPLOY = 1_000_000;
  uint32 public constant MIN_GAS_LIMIT_L2_ADAPTER_DEPLOY = 2_000_000;
  uint32 public constant MIN_GAS_LIMIT_INITIALIZE_TXS = 200_000;
  uint32 public constant MIN_GAS_LIMIT = 8_000_000;

  address public deployer = vm.rememberKey(vm.envUint('MAINNET_DEPLOYER_PK'));

  function run() public {
    // Define the factory constructor args and deploy params struct
    uint256 _salt = block.number + uint256(blockhash(block.number));
    address _owner = vm.envAddress('OWNER_ADDRESS');
    uint256 _l2ChainId = vm.envUint('L2_CHAIN_ID');
    IL1OpUSDCFactory.DeployParams memory _params = IL1OpUSDCFactory.DeployParams({
      usdc: L1_USDC,
      portal: PORTAL,
      l1Messenger: L1_CROSS_DOMAIN_MESSENGER,
      l2Messenger: L2_CROSS_DOMAIN_MESSENGER,
      l1AdapterCreationCode: type(L1OpUSDCBridgeAdapter).creationCode,
      l2AdapterCreationCode: type(L2OpUSDCBridgeAdapter).creationCode,
      usdcProxyCreationCode: USDC_PROXY_BYTECODE,
      usdcImplementationCreationCode: USDC_IMPLEMENTATION_BYTECODE,
      owner: _owner,
      minGasLimit: MIN_GAS_LIMIT
    });

    // Deploy the factory and run the deploy function
    _factoryDeploy(deployer, _params);
  }
}
