// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {FactoryDeploy} from '../FactoryDeploy.sol';
import {L1OpUSDCBridgeAdapter} from 'contracts/L1OpUSDCBridgeAdapter.sol';
import {L2OpUSDCBridgeAdapter} from 'contracts/L2OpUSDCBridgeAdapter.sol';
import {USDC_IMPLEMENTATION_BYTECODE, USDC_PROXY_BYTECODE} from 'contracts/utils/USDCCreationCode.sol';
import {IL1OpUSDCFactory} from 'interfaces/IL1OpUSDCFactory.sol';
import {ICrossDomainMessenger} from 'interfaces/external/ICrossDomainMessenger.sol';
import {IOptimismPortal} from 'interfaces/external/IOptimismPortal.sol';

contract FactoryDeploySepolia is FactoryDeploy {
  ICrossDomainMessenger public constant L1_CROSS_DOMAIN_MESSENGER =
    ICrossDomainMessenger(0x58Cc85b8D04EA49cC6DBd3CbFFd00B4B8D6cb3ef);
  IOptimismPortal public constant PORTAL = IOptimismPortal(0x16Fc5058F25648194471939df75CF27A2fdC48BC);
  address public constant L2_CROSS_DOMAIN_MESSENGER = 0x4200000000000000000000000000000000000007;
  address public constant L1_USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
  address public constant CREATEX = 0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed;
  uint32 public constant MIN_GAS_LIMIT = 12_000_000;

  address public deployer = vm.rememberKey(vm.envUint('SEPOLIA_DEPLOYER_PK'));

  function run() public {
    // Define the factory constructor args and deploy params struct
    uint256 _salt = block.number + uint256(blockhash(block.number - 1));
    address _owner = vm.envAddress('OWNER_ADDRESS');
    uint256 _l2ChainId = vm.envUint('TESTNET_L2_CHAIN_ID');
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
