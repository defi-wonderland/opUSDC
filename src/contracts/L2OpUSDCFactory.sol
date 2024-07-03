// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {L2OpUSDCBridgeAdapter} from 'contracts/L2OpUSDCBridgeAdapter.sol';
import {USDC_PROXY_CREATION_CODE} from 'contracts/utils/USDCProxyCreationCode.sol';
import {IL2OpUSDCFactory} from 'interfaces/IL2OpUSDCFactory.sol';
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
  /**
   * @notice Deploys the USDC implementation, proxy, and L2 adapter contracts all at once, and then initializes the USDC
   * @param _l1Adapter The address of the L1 adapter contract
   * @param _l2AdapterOwner The address of the L2 adapter owner
   * @param _usdcImplementationInitCode The creation code with the constructor arguments for the USDC implementation
   * @param _usdcInitializeData The USDC name, symbol, currency, and decimals used on the first `initialize()` call
   * @param _usdcInitTxs The initialization transactions for the USDC proxy and implementation contracts
   * @dev The USDC proxy owner needs to be set on the first init tx, and will be set to the L2 adapter address
   * @dev Using `CREATE` to guarantee that the addresses are unique among all the L2s
   */
  constructor(
    address _l1Adapter,
    address _l2AdapterOwner,
    bytes memory _usdcImplementationInitCode,
    USDCInitializeData memory _usdcInitializeData,
    bytes[] memory _usdcInitTxs
  ) {
    // Deploy USDC implementation
    (address _usdcImplementation) = _deployCreate(_usdcImplementationInitCode);
    emit USDCImplementationDeployed(_usdcImplementation);

    // Deploy USDC proxy
    bytes memory _usdcProxyCArgs = abi.encode(_usdcImplementation);
    bytes memory _usdcProxyInitCode = bytes.concat(USDC_PROXY_CREATION_CODE, _usdcProxyCArgs);
    (address _usdcProxy) = _deployCreate(_usdcProxyInitCode);
    emit USDCProxyDeployed(_usdcProxy);

    // Deploy L2 Adapter
    address _l2Messenger = 0x4200000000000000000000000000000000000007;
    bytes memory _l2AdapterCArgs = abi.encode(_usdcProxy, _l2Messenger, _l1Adapter, _l2AdapterOwner);
    bytes memory _l2AdapterInitCode = bytes.concat(type(L2OpUSDCBridgeAdapter).creationCode, _l2AdapterCArgs);
    (address _l2Adapter) = _deployCreate(_l2AdapterInitCode);
    emit L2AdapterDeployed(_l2Adapter);

    // Deploy the FallbackProxyAdmin internally in the L2 Adapter to keep it unique
    address _fallbackProxyAdmin = address(L2OpUSDCBridgeAdapter(_l2Adapter).FALLBACK_PROXY_ADMIN());
    // Change the USDC admin so the init txs can be executed over the proxy from this contract
    IUSDC(_usdcProxy).changeAdmin(_fallbackProxyAdmin);

    // Execute the USDC initialization transactions over the USDC contracts
    _executeInitTxs(_usdcImplementation, _usdcInitializeData, _l2Adapter, _usdcInitTxs);
    _executeInitTxs(_usdcProxy, _usdcInitializeData, _l2Adapter, _usdcInitTxs);
  }

  /**
   * @notice Executes the initialization transactions for a target contract
   * @param _usdc The address of the contract to execute the transactions on
   * @param _usdcInitializeData The USDC name, symbol, currency, and decimals used on the first `initialize()` call
   * @param _l2Adapter The address of the L2 adapter
   * @param _initTxs The initialization transactions to execute
   * @dev The first `initialize()` call is defined here to ensure it is properly done, granting the right permissions
   * to the L2 adapter contract. The L2 factory is set as master minter first so it can configure the l2 adapter as
   * unlimited minter and then the master minter is updated again to the l2 adapter
   */
  function _executeInitTxs(
    address _usdc,
    USDCInitializeData memory _usdcInitializeData,
    address _l2Adapter,
    bytes[] memory _initTxs
  ) internal {
    // Initialize the USDC contract
    IUSDC(_usdc).initialize(
      _usdcInitializeData.tokenName,
      _usdcInitializeData.tokenSymbol,
      _usdcInitializeData.tokenCurrency,
      _usdcInitializeData.tokenDecimals,
      address(this),
      _l2Adapter,
      _l2Adapter,
      address(this)
    );

    // Add l2 adapter as unlimited minter
    IUSDC(_usdc).configureMinter(_l2Adapter, type(uint256).max);
    // Set l2 adapter as new master minter
    IUSDC(_usdc).updateMasterMinter(_l2Adapter);
    // Transfer USDC ownership to the L2 adapter
    IUSDC(_usdc).transferOwnership(_l2Adapter);

    // Execute the input init txs, use `_i+1` as revert argument since the first tx is already executed on the contract
    for (uint256 _i; _i < _initTxs.length; _i++) {
      (bool _success,) = _usdc.call(_initTxs[_i]);
      if (!_success) {
        revert IL2OpUSDCFactory_InitializationFailed(_i + 1);
      }
    }
  }

  /**
   * @notice Deploys a new contract via calling the `CREATE` opcode
   * @param _initCode The creation bytecode.
   * @return _newContract The 20-byte address where the contract was deployed.
   */
  function _deployCreate(bytes memory _initCode) internal returns (address _newContract) {
    assembly ("memory-safe") {
      _newContract := create(0x0, add(_initCode, 0x20), mload(_initCode))
    }
    if (_newContract == address(0) || _newContract.code.length == 0) {
      revert IL2OpUSDCFactory_DeploymentFailed();
    }
  }
}
