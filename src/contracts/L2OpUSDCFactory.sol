// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {L2OpUSDCBridgeAdapter} from 'contracts/L2OpUSDCBridgeAdapter.sol';
import {CreateDeployer} from 'contracts/utils/CreateDeployer.sol';
import {USDCInitTxs} from 'contracts/utils/USDCInitTxs.sol';
import {IL2OpUSDCFactory} from 'interfaces/IL2OpUSDCFactory.sol';
import {ICreateX} from 'interfaces/external/ICreateX.sol';

/**
 * @title L1OpUSDCFactory
 * @notice Factory contract to deploy and setup the `L1OpUSDCBridgeAdapter` contract on L1, the
 * `L2OpUSDCBridgeAdapter` and USDC proxy and implementation contracts on L2 on a single transaction.
 */
contract L2OpUSDCFactory is CreateDeployer, IL2OpUSDCFactory {
  event DeployedUSDCProxy(address usdc);
  event DeployedUSDCImpl(address usdc);
  event DeployedL2Adapter(address l2Adapter);

  constructor(
    bytes memory _l2AdapterCreationCode,
    bytes memory _usdcProxyCreationCode,
    bytes memory _usdcImplCreationCode
  ) {
    // deploy usdc
    // Deploy usdc on L2 tx
    address _implt = deployCreate2(SALT, _usdcImplCreationCode);
    emit DeployedUSDCImpl(_implt);

    bytes memory _usdcProxyInitCode = bytes.concat(_usdcProxyCreationCode, abi.encode(_implt));
    address _proxy = deployCreate2(SALT, _usdcProxyInitCode);
    emit DeployedUSDCProxy(_proxy);

    // Deploy l2 adapter
    address _adapter = deployCreate2(SALT, _l2AdapterCreationCode);
    emit DeployedL2Adapter(_adapter);
  }
}

// contract Deployer {
//   function deploy() public {
//     // Define the factory constructor args and deploy params struct
//     uint256 _salt = block.number + uint256(blockhash(block.number - 1));
//     address _l1Adapter = address(0);
//     bytes memory _l2AdapterCreationCode = type(L2OpUSDCBridgeAdapter).creationCode;
//     bytes memory _usdcProxyCreationCode = bytes('');
//     bytes memory _usdcImplCreationCode = bytes('');

//     // Deploy the factory and run the deploy function
//     new L2OpUSDCFactory(_l1Adapter, _l2AdapterCreationCode, _usdcProxyCreationCode, _usdcImplCreationCode);
//   }
// }
