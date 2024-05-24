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
  constructor(
    bytes memory _usdcProxyInitCode,
    bytes memory _usdcImplBytecode,
    bytes[] memory _usdcImplInitTxs,
    bytes memory _l2AdapterBytecode,
    bytes[] memory _l2AdapterInitTxs
  ) {
    // Deploy usdc implementation
    address _usdcImplementation = address(new BytecodeDeployer(_usdcImplBytecode));
    emit DeployedUSDCImpl(_usdcImplementation);

    // Deploy usdc proxy
    address _usdcProxy = _createDeploy(_usdcProxyInitCode);
    emit DeployedUSDCProxy(_usdcProxy);

    // Deploy l2 adapter
    address _adapter = address(new BytecodeDeployer(_l2AdapterBytecode));
    emit DeployedL2Adapter(_adapter);

    // Execute the USDC initialization transactions
    if (_usdcImplInitTxs.length > 0) {
      // Initialize usdc implementation
      for (uint256 i = 0; i < _usdcImplInitTxs.length; i++) {
        (bool _success,) = _usdcImplementation.call(_usdcImplInitTxs[i]);
        if (!_success) {
          revert IL2OpUSDCFactory_UsdcInitializationFailed();
        }
      }
    }

    // Execute the L2 Adapter initialization transactions
    if (_l2AdapterInitTxs.length > 0) {
      // Initialize l2 adapter
      for (uint256 i = 0; i < _l2AdapterInitTxs.length; i++) {
        (bool _success,) = _adapter.call(_l2AdapterInitTxs[i]);
        if (!_success) {
          revert IL2OpUSDCFactory_AdapterInitializationFailed();
        }
      }
    }
  }

  /**
   * @dev Deploys a new contract through the `CREATE` opcode
   * @param _initCode The creation bytecode (contract initialization code + constructor arguments)
   * @return _newContract The address where the contract was deployed
   */
  function _createDeploy(bytes memory _initCode) internal returns (address _newContract) {
    assembly ("memory-safe") {
      _newContract := create(0, add(_initCode, 0x20), mload(_initCode))
    }
    if (_newContract == address(0) || _newContract.code.length == 0) {
      revert IL2OpUSDCFactory_CreateDeploymentFailed();
    }
  }
}
