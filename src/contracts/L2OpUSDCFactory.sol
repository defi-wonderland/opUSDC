// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BytecodeDeployer} from 'contracts/BytecodeDeployer.sol';
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

  constructor(bytes memory _l2AdapterBytecode, bytes memory _usdcProxyBytecode, bytes memory _usdcImplBytecode) {
    // deploy usdc impl
    address _implt = address(new BytecodeDeployer(_usdcImplBytecode));
    emit DeployedUSDCImpl(_implt);

    // deploy usdc proxy
    // bytes memory _usdcProxyInitCode = bytes.concat(_usdcProxyCreationCode, abi.encode(_implt));
    // address _proxy = deployCreate2(_usdcProxyInitCode);
    // TODO: check well this
    address _proxy = address(new BytecodeDeployer(_usdcProxyBytecode));
    emit DeployedUSDCProxy(_proxy);

    // Deploy l2 adapter
    address _adapter = address(new BytecodeDeployer(_l2AdapterBytecode));
    emit DeployedL2Adapter(_adapter);
  }
}
