// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC1967Proxy} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import {ERC1967Utils} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol';

import {BytecodeDeployer} from 'contracts/utils/BytecodeDeployer.sol';
import {USDC_PROXY_CREATION_CODE} from 'contracts/utils/USDCProxyCreationCode.sol';

import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import {IL2OpUSDCFactory} from 'interfaces/IL2OpUSDCFactory.sol';
import {ICrossDomainMessenger} from 'interfaces/external/ICrossDomainMessenger.sol';
import {IUSDC} from 'interfaces/external/IUSDC.sol';

import 'forge-std/Test.sol';

/**
 * @title L2OpUSDCFactory
 * @notice Factory contract for deploying the L2 USDC implementation, proxy, and `L2OpUSDCBridgeAdapter` contracts all
 * at once on the constructor
 */
contract L2OpUSDCFactory is IL2OpUSDCFactory {
  address public constant L2_MESSENGER = 0x4200000000000000000000000000000000000007;

  address internal constant _WETH = 0x4200000000000000000000000000000000000006;

  address public immutable L1_FACTORY;

  bytes32 internal immutable _SALT;

  /**
   * @notice Deploys the USDC implementation, proxy, and L2 adapter contracts
   * @param _salt The salt value used to deploy the contracts
   * @param _l1Factory The address of the L1 factory contract
   */
  constructor(bytes32 _salt, address _l1Factory) {
    _SALT = _salt;
    L1_FACTORY = _l1Factory;
  }

  /**
   * @notice Deploys the USDC implementation, proxy, and L2 adapter implementation and proxy contracts
   * @param _usdcImplBytecode The bytecode for the USDC implementation contract
   * @param _usdcImplInitTxs The initialization transactions for the USDC implementation contract
   * @param _usdcAdmin The address of the USDC admin
   * @param _l2AdapterBytecode The bytecode for the L2 adapter contract
   * @param _l2AdapterInitTxs The initialization transactions for the L2 adapter contract
   * @dev It always deploys the proxies with WETH as the implementation, and then upgrades them so their address
   * is always the same in all the chains, regardless of the implementation code.
   */
  function deploy(
    bytes memory _usdcImplBytecode,
    bytes[] memory _usdcImplInitTxs,
    address _usdcAdmin,
    bytes memory _l2AdapterBytecode,
    bytes[] memory _l2AdapterInitTxs
  ) external {
    if (msg.sender != L2_MESSENGER || ICrossDomainMessenger(L2_MESSENGER).xDomainMessageSender() != L1_FACTORY) {
      revert IL2OpUSDCFactory_InvalidSender();
    }

    bytes memory _bytecodeDeployerCreationCode = type(BytecodeDeployer).creationCode;
    address _usdcImplementation;
    address _usdcProxy;
    {
      // Deploy usdc implementation
      bytes memory _usdcImplInitCode = bytes.concat(_bytecodeDeployerCreationCode, abi.encode(_usdcImplBytecode));
      _usdcImplementation = _deployCreate2(_SALT, _usdcImplInitCode);
      // Deploy usdc proxy
      bytes memory _usdcProxyCArgs = abi.encode(_WETH);
      bytes memory _usdcProxyInitCode = bytes.concat(USDC_PROXY_CREATION_CODE, _usdcProxyCArgs);
      _usdcProxy = _deployCreate2(_SALT, _usdcProxyInitCode);
      IUSDC(_usdcProxy).upgradeTo(_usdcImplementation);
      emit USDCDeployed(_usdcProxy, _usdcImplementation);
    }

    address _adapterProxy;
    uint256 _length = _usdcImplInitTxs.length;
    {
      // Deploy L2 adapter implementation
      bytes memory _l2AdapterImplInitCode = bytes.concat(_bytecodeDeployerCreationCode, abi.encode(_l2AdapterBytecode));
      address _adapterImplementation = _deployCreate2(_SALT, _l2AdapterImplInitCode);
      // Deploy L2 adapter proxy
      bytes memory _proxyCArgs = abi.encode(_WETH, '');
      bytes memory _adapterProxyInitCode = bytes.concat(type(ERC1967Proxy).creationCode, _proxyCArgs);
      _adapterProxy = _deployCreate2(_SALT, _adapterProxyInitCode);
      // Upgrade the proxy and set the number of initialization transactions that will be executed by the USDC proxy
      bytes memory _adapterInitTx = abi.encodeWithSignature('setProxyExecutedInitTxs(uint256)', _length);
      UUPSUpgradeable(_adapterProxy).upgradeToAndCall(_adapterImplementation, _adapterInitTx);
      emit AdapterDeployed(_adapterProxy, _adapterImplementation);
    }

    // Execute the USDC initialization transactions, if any
    if (_length > 0) {
      _executeInitTxs(_usdcImplementation, _usdcImplInitTxs, _length);
      IUSDC(_usdcProxy).changeAdmin(_usdcAdmin);
      _executeInitTxs(_usdcProxy, _usdcImplInitTxs, _length);
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
