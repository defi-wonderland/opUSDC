// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC1967Proxy} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import {BytecodeDeployer} from 'contracts/utils/BytecodeDeployer.sol';
import {IL2OpUSDCFactory} from 'interfaces/IL2OpUSDCFactory.sol';

// TODO: Move
interface IProxy {
  function upgradeTo(address _implementation) external;
}

/**
 * @title L2OpUSDCFactory
 * @notice Factory contract for deploying the L2 USDC implementation, proxy, and `L2OpUSDCBridgeAdapter` contracts all
 * at once on the constructor
 */
contract L2OpUSDCFactory is IL2OpUSDCFactory {
  /**
   * @notice Deploys the USDC implementation, proxy, and L2 adapter contracts
   * @param _salt The salt value used to deploy the contracts
   * @param _usdcProxyCreationCode The creation code plus the constructor arguments for the USDC proxy contract
   * @param _usdcImplBytecode The bytecode for the USDC implementation contract
   * @param _usdcImplInitTxs The initialization transactions for the USDC implementation contract
   * @param _l2AdapterBytecode The bytecode for the L2 adapter contract
   * @param _l2AdapterInitTxs The initialization transactions for the L2 adapter contract
   * @dev It always deploys the proxies with zero address as the implementation, and then upgrades them so their address
   * is always the same in all the chains, regardless of the implementation code
   */
  constructor(
    bytes32 _salt,
    bytes memory _usdcProxyCreationCode,
    bytes memory _usdcImplBytecode,
    bytes[] memory _usdcImplInitTxs,
    bytes memory _l2AdapterBytecode,
    bytes[] memory _l2AdapterInitTxs
  ) {
    // Deploy usdc implementation
    bytes memory _bytecodeDeployerCreationCode = type(BytecodeDeployer).creationCode;
    address _usdcImplementation;
    {
      bytes memory _usdcImplInitCode = bytes.concat(_bytecodeDeployerCreationCode, _usdcImplBytecode);
      _usdcImplementation = _deployCreate2(_salt, _usdcImplInitCode);
      // Deploy usdc proxy
      bytes memory _usdcProxyCArgs = abi.encode(address(0));
      bytes memory _usdcProxyInitCode =
        bytes.concat(_bytecodeDeployerCreationCode, _usdcProxyCreationCode, _usdcProxyCArgs);
      address _usdcProxy = _deployCreate2(_salt, _usdcProxyInitCode);
      IProxy(_usdcProxy).upgradeTo(_usdcImplementation);
      emit USDCDeployed(_usdcProxy, _usdcImplementation);
    }

    address _adapterProxy;
    {
      // Deploy L2 adapter implementation
      bytes memory _l2AdapterImplInitCode = bytes.concat(_bytecodeDeployerCreationCode, _l2AdapterBytecode);
      address _adapterImplementation = _deployCreate2(_salt, _l2AdapterImplInitCode);
      // Deploy L2 adapter proxy
      bytes memory _proxyCArgs = abi.encode(address(0), '');
      bytes memory _adapterProxyInitCode =
        bytes.concat(_bytecodeDeployerCreationCode, type(ERC1967Proxy).creationCode, _proxyCArgs);
      _adapterProxy = _deployCreate2(_salt, _adapterProxyInitCode);
      IProxy(_adapterProxy).upgradeTo(_adapterImplementation);
      emit AdapterDeployed(_adapterProxy, _adapterImplementation);
    }

    // Execute the USDC initialization transactions, if any
    uint256 _length = _usdcImplInitTxs.length;
    if (_length > 0) {
      _executeInitTxs(_usdcImplementation, _usdcImplInitTxs, _length);
    }

    // Execute the L2 adapter initialization transactions, if any
    _length = _l2AdapterInitTxs.length;
    if (_length > 0) {
      _executeInitTxs(_adapterProxy, _l2AdapterInitTxs, _length);
    }
  }

  /**
   * @notice Executes the initialization transactions for a target contract
   * @param _target The address of the contract to execute the transactions on
   * @param _initTxs The initialization transactions to execute
   * @param _length The number of transactions to execute
   */
  function _executeInitTxs(address _target, bytes[] memory _initTxs, uint256 _length) internal {
    for (uint256 i = 0; i < _length; i++) {
      (bool _success,) = _target.call(_initTxs[i]);
      if (!_success) {
        revert IL2OpUSDCFactory_InitializationFailed();
      }
    }
  }

  /**
   * @dev Deploys a new contract via calling the `CREATE2` opcode and using the salt value `salt`,
   * the creation bytecode `initCode`, and `msg.value` as inputs. In order to save deployment costs,
   * we do not sanity check the `initCode` length. Note that if `msg.value` is non-zero, `initCode`
   * must have a `payable` constructor.
   * @param _salt The 32-byte random value used to create the contract address.
   * @param _initCode The creation bytecode.
   * @return _newContract The 20-byte address where the contract was deployed.
   */
  function _deployCreate2(bytes32 _salt, bytes memory _initCode) public payable returns (address _newContract) {
    assembly ("memory-safe") {
      _newContract := create2(callvalue(), add(_initCode, 0x20), mload(_initCode), _salt)
    }
    if (_newContract == address(0) || _newContract.code.length == 0) {
      revert IL2OpUSDCFactory_Create2DeploymentFailed();
    }
  }
}
