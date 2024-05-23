// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BytecodeDeployer} from 'contracts/BytecodeDeployer.sol';
import {L2OpUSDCBridgeAdapter} from 'contracts/L2OpUSDCBridgeAdapter.sol';
import {USDCInitTxs} from 'contracts/utils/USDCInitTxs.sol';
import {IL2OpUSDCFactory} from 'interfaces/IL2OpUSDCFactory.sol';

/**
 * @title L1OpUSDCFactory
 * @notice Factory contract to deploy and setup the `L1OpUSDCBridgeAdapter` contract on L1, the
 * `L2OpUSDCBridgeAdapter` and USDC proxy and implementation contracts on L2 on a single transaction.
 */
contract L2OpUSDCFactory is IL2OpUSDCFactory {
  constructor(bytes memory _l2AdapterBytecode, bytes memory _usdcProxyInitCode, bytes memory _usdcImplBytecode) {
    // Deploy usdc implementation
    address _implt = address(new BytecodeDeployer(_usdcImplBytecode));
    emit DeployedUSDCImpl(_implt);

    // Deploy usdc proxy
    address _proxy = createDeploy(_usdcProxyInitCode);
    emit DeployedUSDCProxy(_proxy);

    // Deploy l2 adapter
    address _adapter = address(new BytecodeDeployer(_l2AdapterBytecode));
    emit DeployedL2Adapter(_adapter);
  }

  /**
   * @dev Deploys a new contract through the `CREATE` opcode
   * @param _initCode The creation bytecode (contract initialization code + constructor arguments)
   * @return _newContract The address where the contract was deployed
   */
  function createDeploy(bytes memory _initCode) public returns (address _newContract) {
    assembly ("memory-safe") {
      _newContract := create(0, add(_initCode, 0x20), mload(_initCode))
    }
    if (_newContract == address(0) || _newContract.code.length == 0) {
      revert IL2OpUSDCBridgeAdapter_CreateDeploymentFailed();
    }
  }
}
