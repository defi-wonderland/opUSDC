// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC1967Proxy} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import {BytecodeDeployer} from 'contracts/utils/BytecodeDeployer.sol';
import {IL2OpUSDCFactory} from 'interfaces/IL2OpUSDCFactory.sol';

/**
 * @title L2OpUSDCFactory
 * @notice Factory contract for deploying the L2 USDC implementation, proxy, and `L2OpUSDCBridgeAdapter` contracts all
 * at once on the constructor
 */
contract L2OpUSDCFactory is IL2OpUSDCFactory {
  /**
   * @notice Deploys the USDC implementation, proxy, and L2 adapter contracts
   * @param _usdcProxyInitCode The creation code plus the constructor arguments for the USDC proxy contract
   * @param _usdcImplBytecode The bytecode for the USDC implementation contract
   * @param _usdcImplInitTxs The initialization transactions for the USDC implementation contract
   * @param _l2AdapterBytecode The bytecode for the L2 adapter contract
   * @param _l2AdapterInitTxs The initialization transactions for the L2 adapter contract
   */
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

    // Deploy L2 adapter implementation
    address _adapterImplementation = address(new BytecodeDeployer(_l2AdapterBytecode));
    emit DeployedL2AdapterImplementation(_adapterImplementation);

    uint256 _usdcImplInitTxsLength = _usdcImplInitTxs.length;

    // Deploy L2 adapter proxy
    bytes memory _adapterInitTx = abi.encodeWithSignature('setLastL2UsdcInitTxsLength(uint256)', _usdcImplInitTxsLength);
    address _adapterProxy = address(new ERC1967Proxy(_adapterImplementation, _adapterInitTx));
    emit DeployedL2AdapterProxy(_adapterProxy);

    bool _success;

    // Execute the USDC initialization transactions
    if (_usdcImplInitTxsLength > 0) {
      // Initialize usdc implementation
      for (uint256 i; i < _usdcImplInitTxsLength; i++) {
        (_success,) = _usdcImplementation.call(_usdcImplInitTxs[i]);
        if (!_success) {
          revert IL2OpUSDCFactory_UsdcInitializationFailed();
        }
      }
    }

    // Execute the L2 Adapter initialization transactions
    uint256 _l2AdapterInitTxsLength = _l2AdapterInitTxs.length;
    // Initialize L2 adapter
    for (uint256 i; i < _l2AdapterInitTxsLength; i++) {
      (_success,) = _adapterProxy.call(_l2AdapterInitTxs[i]);
      if (!_success) {
        revert IL2OpUSDCFactory_AdapterInitializationFailed();
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
