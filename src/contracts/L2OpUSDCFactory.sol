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
   * @param _usdcInitializeData The USDC name, symbol, currency, and decimals used on the first `initialize()` call
   * @param _usdcInitTxs The initialization transactions for the USDC proxy and implementation contracts
   * @dev The USDC proxy owner needs to be set on the first init tx, and will be set to the L2 adapter address
   * @dev Using `CREATE` to guarantee that the addresses are unique among all the L2s
   * @dev No external call should ever cause this function to revert, it will instead emit a failure event
   */
  function deploy(
    address _l1Adapter,
    address _l2AdapterOwner,
    bytes calldata _usdcImplementationInitCode,
    USDCInitializeData calldata _usdcInitializeData,
    bytes[] memory _usdcInitTxs
  ) external {
    if (msg.sender != L2_MESSENGER || ICrossDomainMessenger(L2_MESSENGER).xDomainMessageSender() != L1_FACTORY) {
      revert IL2OpUSDCFactory_InvalidSender();
    }

    // Deploy USDC implementation
    (address _usdcImplementation, bool _usdcImplSuccess) = _deployCreate(_usdcImplementationInitCode);
    if (_usdcImplSuccess) emit USDCImplementationDeployed(_usdcImplementation);

    // Deploy USDC proxy
    bytes memory _args = abi.encode(_usdcImplementation);
    bytes memory _initCode = bytes.concat(USDC_PROXY_CREATION_CODE, _args);
    (address _usdcProxy, bool _usdcProxySuccess) = _deployCreate(_initCode);
    if (_usdcProxySuccess) emit USDCProxyDeployed(_usdcProxy);

    // Deploy L2 Adapter
    _args = abi.encode(_usdcProxy, msg.sender, _l1Adapter, _l2AdapterOwner);
    _initCode = bytes.concat(type(L2OpUSDCBridgeAdapter).creationCode, _args);
    (address _l2Adapter, bool _l2AdapterSuccess) = _deployCreate(_initCode);
    if (_l2AdapterSuccess) emit L2AdapterDeployed(_l2Adapter);

    if (!_usdcImplSuccess || !_usdcProxySuccess || !_l2AdapterSuccess) {
      // If any deployments failed we return early
      return;
    }

    // Deploy the FallbackProxyAdmin internally in the L2 Adapter to keep it unique
    address _fallbackProxyAdmin = address(L2OpUSDCBridgeAdapter(_l2Adapter).FALLBACK_PROXY_ADMIN());
    // Change the USDC admin so the init txs can be executed over the proxy from this contract
    bytes memory _usdcChangeAdmin = abi.encodeWithSelector(IUSDC.changeAdmin.selector, _fallbackProxyAdmin);

    (_usdcProxySuccess,) = _usdcProxy.call(_usdcChangeAdmin);
    if (!_usdcProxySuccess) {
      emit ChangeAdminFailed(_fallbackProxyAdmin);
      return;
    }

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
    USDCInitializeData calldata _usdcInitializeData,
    address _l2Adapter,
    bytes[] memory _initTxs
  ) internal {
    // Initialize the USDC contract

    // We need to make all of these low level calls to ensure this function never reverts
    // Instead of reverting we will emit a failed event for each step
    bytes memory _initialize = abi.encodeWithSelector(
      IUSDC.initialize.selector,
      _usdcInitializeData._tokenName,
      _usdcInitializeData._tokenSymbol,
      _usdcInitializeData._tokenCurrency,
      _usdcInitializeData._tokenDecimals,
      address(this),
      _l2Adapter,
      _l2Adapter,
      address(this)
    );

    bytes memory _configureMinter =
      abi.encodeWithSelector(IUSDC.configureMinter.selector, _l2Adapter, type(uint256).max);

    bytes memory _updateMasterMinter = abi.encodeWithSelector(IUSDC.updateMasterMinter.selector, _l2Adapter);

    bytes memory _transferOwnership = abi.encodeWithSelector(IUSDC.transferOwnership.selector, _l2Adapter);

    bool _success;

    // NOTE: If any of these calls fail we assume they will all fail because they are chained calls.
    // So we return early to save gas

    // Initialize USDC
    (_success,) = _usdc.call(_initialize);
    if (!_success) {
      emit InitializationFailed(0);
      return;
    }

    // Add l2 adapter as unlimited minter
    (_success,) = _usdc.call(_configureMinter);
    if (!_success) {
      emit ConfigureMinterFailed(_l2Adapter);
      return;
    }

    // Set l2 adapter as new master minter
    (_success,) = _usdc.call(_updateMasterMinter);
    if (!_success) {
      emit UpdateMasterMinterFailed(_l2Adapter);
      return;
    }

    // Transfer USDC ownership to the L2 adapter
    (_success,) = _usdc.call(_transferOwnership);
    if (!_success) {
      emit TransferOwnershipFailed(_l2Adapter);
      return;
    }

    for (uint256 _i; _i < _initTxs.length; _i++) {
      (_success,) = _usdc.call(_initTxs[_i]);
      if (!_success) {
        emit InitializationFailed(_i + 1);
        return;
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
