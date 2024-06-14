// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {L2OpUSDCBridgeAdapter} from 'contracts/L2OpUSDCBridgeAdapter.sol';
import {USDC_PROXY_CREATION_CODE} from 'contracts/utils/USDCProxyCreationCode.sol';
import {IL2OpUSDCFactory} from 'interfaces/IL2OpUSDCFactory.sol';
import {ICrossDomainMessenger} from 'interfaces/external/ICrossDomainMessenger.sol';
import {IUSDC} from 'interfaces/external/IUSDC.sol';

/**
 * @title L2OpUSDCFactory
 * @notice Factory contract for deploying the L2 USDC implementation, proxy, and `L2OpUSDCBridgeAdapter` contract,
 * all at once on the `deploy` function.
 * @dev The salt is always different for each deployed instance of this contract on the L1 Factory, and the L2 contracts
 * are deployed with `CREATE` to guarantee that the addresses are unique among all the L2s, so we avoid a scenario where
 * L2 contracts have the same address on different L2s when triggered by different owners.
 */
contract L2OpUSDCFactory is IL2OpUSDCFactory {
  /// @inheritdoc IL2OpUSDCFactory
  address public constant L2_MESSENGER = 0x4200000000000000000000000000000000000007;

  /// @inheritdoc IL2OpUSDCFactory
  address public immutable L1_FACTORY;

  /**
   * @notice Constructs the L2 factory contract
   * @param _l1Factory The address of the L1 factory contract
   */
  constructor(address _l1Factory) {
    L1_FACTORY = _l1Factory;
  }

  /**
   * @notice Deploys the USDC implementation, proxy, and L2 adapter contracts all at once, and then initializes the USDC
   * @param _l1Adapter The address of the L1 adapter contract
   * @param _l2AdapterOwner The address of the L2 adapter owner
   * @param _usdcImplementationInitCode The creation code with the constructor arguments for the USDC implementation
   * @param _usdcInitTxs The initialization transactions for the USDC proxy and implementation contracts
   * @dev The USDC proxy owner needs to be set on the first init tx, and will be set to the L2 adapter address
   * @dev Using `CREATE` to guarantee that the addresses are unique among all the L2s
   */
  function deploy(
    address _l1Adapter,
    address _l2AdapterOwner,
    bytes memory _usdcImplementationInitCode,
    bytes[] memory _usdcInitTxs
  ) external {
    if (msg.sender != L2_MESSENGER || ICrossDomainMessenger(L2_MESSENGER).xDomainMessageSender() != L1_FACTORY) {
      revert IL2OpUSDCFactory_InvalidSender();
    }

    // Deploy USDC implementation
    (address _usdcImplementation, bool _usdcImplSuccess) = _deployCreate(_usdcImplementationInitCode);
    if (_usdcImplSuccess) emit USDCImplementationDeployed(_usdcImplementation);

    // Deploy USDC proxy
    bytes memory _usdcProxyCArgs = abi.encode(_usdcImplementation);
    bytes memory _usdcProxyInitCode = bytes.concat(USDC_PROXY_CREATION_CODE, _usdcProxyCArgs);
    (address _usdcProxy, bool _usdcProxySuccess) = _deployCreate(_usdcProxyInitCode);
    if (_usdcProxySuccess) emit USDCProxyDeployed(_usdcProxy);

    // Deploy L2 Adapter
    bytes memory _l2AdapterCArgs = abi.encode(_usdcProxy, msg.sender, _l1Adapter, _l2AdapterOwner);
    bytes memory _l2AdapterInitCode = bytes.concat(type(L2OpUSDCBridgeAdapter).creationCode, _l2AdapterCArgs);
    (address _l2Adapter, bool _l2AdapterSuccess) = _deployCreate(_l2AdapterInitCode);
    if (_l2AdapterSuccess) emit L2AdapterDeployed(_l2Adapter);

    // We need to first deploy everything and then revert so we can always track the nonce on the L1 factory
    if (!_usdcImplSuccess || !_usdcProxySuccess || !_l2AdapterSuccess) {
      revert IL2OpUSDCFactory_DeploymentsFailed();
    }

    // Change the USDC admin so the init txs can be executed over the proxy from this contract
    IUSDC(_usdcProxy).changeAdmin(_l2Adapter);

    // Execute the USDC initialization transactions
    _executeInitTxs(_usdcImplementation, _usdcInitTxs, _usdcInitTxs.length);
    _executeInitTxs(_usdcProxy, _usdcInitTxs, _usdcInitTxs.length);
  }

  /**
   * @notice Executes the initialization transactions for a target contract
   * @param _target The address of the contract to execute the transactions on
   * @param _initTxs The initialization transactions to execute
   * @param _length The number of transactions to execute
   */
  function _executeInitTxs(address _target, bytes[] memory _initTxs, uint256 _length) internal {
    for (uint256 _i; _i < _length; _i++) {
      (bool _success,) = _target.call(_initTxs[_i]);
      if (!_success) {
        revert IL2OpUSDCFactory_InitializationFailed();
      }
    }
  }

  /**
   * @notice Deploys a new contract via calling the `CREATE` opcode
   * @param _initCode The creation bytecode.
   * @return _newContract The 20-byte address where the contract was deployed.
   */
  function _deployCreate(bytes memory _initCode) internal returns (address _newContract, bool _success) {
    assembly ("memory-safe") {
      _newContract := create(0x0, add(_initCode, 0x20), mload(_initCode))
    }
    if (_newContract == address(0) || _newContract.code.length == 0) {
      emit CreateDeploymentFailed();
    } else {
      _success = true;
    }
  }
}
