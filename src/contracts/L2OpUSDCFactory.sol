// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import {ERC1967Proxy} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import {L2OpUSDCBridgeAdapter} from 'contracts/L2OpUSDCBridgeAdapter.sol';
import {BytecodeDeployer} from 'contracts/utils/BytecodeDeployer.sol';
import {USDC_PROXY_CREATION_CODE} from 'contracts/utils/USDCProxyCreationCode.sol';
import {IL2OpUSDCFactory} from 'interfaces/IL2OpUSDCFactory.sol';
import {ICrossDomainMessenger} from 'interfaces/external/ICrossDomainMessenger.sol';
import {IUSDC} from 'interfaces/external/IUSDC.sol';

/**
 * @title L2OpUSDCFactory
 * @notice Factory contract for deploying the L2 USDC implementation, proxy, and `L2OpUSDCBridgeAdapter` contract,
 * all at once on the `deploy` function.
 */
contract L2OpUSDCFactory is IL2OpUSDCFactory {
  /// @inheritdoc IL2OpUSDCFactory
  address public constant L2_MESSENGER = 0x4200000000000000000000000000000000000007;

  /// @notice The empty bytes constant
  bytes internal constant _EMPTY_BYTES = '';

  /// @inheritdoc IL2OpUSDCFactory
  address public immutable L1_FACTORY;

  /// @notice The salt value used to deploy the contracts
  bytes32 internal immutable _SALT;

  /**
   * @notice Constructs the L2 factory contract
   * @param _salt The salt value used to deploy the contracts
   * @param _l1Factory The address of the L1 factory contract
   */
  constructor(bytes32 _salt, address _l1Factory) {
    L1_FACTORY = _l1Factory;
    _SALT = _salt;
  }

  function deploy(address _l1Adapter, bytes memory _usdcImplementationCode, bytes[] memory _usdcInitTxs) external {
    if (msg.sender != L2_MESSENGER || ICrossDomainMessenger(L2_MESSENGER).xDomainMessageSender() != L1_FACTORY) {
      revert IL2OpUSDCFactory_InvalidSender();
    }

    // Deploy USDC proxy
    bytes memory _usdcProxyCArgs = abi.encode(_l1Adapter, _EMPTY_BYTES);
    bytes memory _usdcProxyInitCode = bytes.concat(USDC_PROXY_CREATION_CODE, _usdcProxyCArgs);
    address _usdcProxy = _deployCreate2(_SALT, _usdcProxyInitCode);

    // Deploy USDC implementation
    bytes memory _usdcImplInitCode = bytes.concat(type(BytecodeDeployer).creationCode, _usdcImplementationCode);
    address _usdcImplementation = _deployCreate2(_SALT, _usdcImplInitCode);

    // Deploy L2 Adapter
    bytes memory _l2AdapterCArgs = abi.encode(_usdcProxy, msg.sender, _l1Adapter);
    bytes memory _l2AdapterInitCode = bytes.concat(type(ERC1967Proxy).creationCode, _l2AdapterCArgs);
    address _l2Adapter = _deployCreate2(_SALT, _l2AdapterInitCode);

    // Upgrade the USDC proxy to the implementation
    IUSDC(_usdcProxy).upgradeTo(_usdcImplementation);

    // Change the USDC admin so the init txs can be executed over the proxy from this contract
    IUSDC(_usdcProxy).changeAdmin(_l2Adapter);
    // Execute the USDC initialization transactions
    _executeInitTxs(_usdcProxy, _usdcInitTxs, _usdcInitTxs.length);
    _executeInitTxs(_usdcImplementation, _usdcInitTxs, _usdcInitTxs.length);

    // TODO: Transfer ownership TBD
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
   * @notice Deploys a contract using the `CREATE2` opcode
   * @param _salt The random value to be used to create the contract address
   * @param _initCode The creation bytecode
   * @return _newContract The address where the contract was deployed
   */
  function _deployCreate2(bytes32 _salt, bytes memory _initCode) internal returns (address _newContract) {
    assembly ("memory-safe") {
      _newContract := create2(0x0, add(_initCode, 0x20), mload(_initCode), _salt)
    }
    if (_newContract == address(0) || _newContract.code.length == 0) {
      revert IL2OpUSDCFactory_Create2DeploymentFailed();
    }
  }
}
