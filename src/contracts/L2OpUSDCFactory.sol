// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC1967Proxy} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import {ERC1967Utils} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol';

import {BytecodeDeployer} from 'contracts/utils/BytecodeDeployer.sol';
import {IL2OpUSDCFactory} from 'interfaces/IL2OpUSDCFactory.sol';
import {ICrossDomainMessenger} from 'interfaces/external/ICrossDomainMessenger.sol';

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
  address public constant L2_MESSENGER = 0x4200000000000000000000000000000000000007;

  address public immutable L1_FACTORY;

  bytes32 public immutable SALT;

  // TODO: Add zero address and empty bytes?

  /**
   * @notice Deploys the USDC implementation, proxy, and L2 adapter contracts
   * @param _salt The salt value used to deploy the contracts
   */
  constructor(bytes32 _salt, address _l1Factory) {
    SALT = _salt;
    L1_FACTORY = _l1Factory;
  }

  /**
   * @notice Deploys the USDC implementation, proxy, and L2 adapter implementation and proxy contracts
   * @param _usdcProxyCreationCode The creation code plus the constructor arguments for the USDC proxy contract
   * @param _usdcImplBytecode The bytecode for the USDC implementation contract
   * @param _usdcImplInitTxs The initialization transactions for the USDC implementation contract
   * @param _l2AdapterBytecode The bytecode for the L2 adapter contract
   * @param _l2AdapterInitTxs The initialization transactions for the L2 adapter contract
   * @dev It always deploys the proxies with zero address as the implementation, and then upgrades them so their address
   * is always the same in all the chains, regardless of the implementation code
   */
  function deploy(
    bytes memory _usdcProxyCreationCode,
    bytes memory _usdcImplBytecode,
    bytes[] memory _usdcImplInitTxs,
    bytes memory _l2AdapterBytecode,
    bytes[] memory _l2AdapterInitTxs
  ) external {
    // TODO: Only messenger can call
    if (msg.sender != L2_MESSENGER || ICrossDomainMessenger(L2_MESSENGER).xDomainMessageSender() != L1_FACTORY) {
      revert IL2OpUSDCFactory_InvalidSender();
    }

    bytes memory _bytecodeDeployerCreationCode = type(BytecodeDeployer).creationCode;
    address _usdcImplementation;
    address _usdcProxy;
    {
      // Deploy usdc implementation
      bytes memory _usdcImplInitCode = bytes.concat(_bytecodeDeployerCreationCode, abi.encode(_usdcImplBytecode));
      _usdcImplementation = _deployCreate2(SALT, _usdcImplInitCode);
      // Deploy usdc proxy
      bytes memory _usdcProxyCArgs = abi.encode(address(0));
      bytes memory _usdcProxyInitCode =
        bytes.concat(_bytecodeDeployerCreationCode, abi.encode(_usdcProxyCreationCode, _usdcProxyCArgs));
      _usdcProxy = _deployCreate2(SALT, _usdcProxyInitCode);
      IProxy(_usdcProxy).upgradeTo(_usdcImplementation);
      emit USDCDeployed(_usdcProxy, _usdcImplementation);
    }

    address _adapterProxy;
    {
      // Deploy L2 adapter implementation
      bytes memory _l2AdapterImplInitCode = bytes.concat(_bytecodeDeployerCreationCode, abi.encode(_l2AdapterBytecode));
      address _adapterImplementation = _deployCreate2(SALT, _l2AdapterImplInitCode);
      // Deploy L2 adapter proxy
      bytes memory _proxyCArgs = abi.encode(address(0), '');
      bytes memory _adapterProxyInitCode =
        bytes.concat(_bytecodeDeployerCreationCode, abi.encode(type(ERC1967Proxy).creationCode, _proxyCArgs));
      _adapterProxy = _deployCreate2(SALT, _adapterProxyInitCode);
      // Store the implementation in the proxy contract
      bytes32 _implementationSlot = ERC1967Utils.IMPLEMENTATION_SLOT;
      assembly {
        sstore(_implementationSlot, _adapterImplementation)
      }
      emit AdapterDeployed(_adapterProxy, _adapterImplementation);
    }

    // Execute the USDC initialization transactions, if any
    uint256 _length = _usdcImplInitTxs.length;
    if (_length > 0) {
      _executeInitTxs(_usdcImplementation, _usdcImplInitTxs, _length);
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
  function _deployCreate2(bytes32 _salt, bytes memory _initCode) public payable returns (address _newContract) {
    assembly ("memory-safe") {
      _newContract := create2(callvalue(), add(_initCode, 0x20), mload(_initCode), _salt)
    }
    if (_newContract == address(0) || _newContract.code.length == 0) {
      revert IL2OpUSDCFactory_Create2DeploymentFailed();
    }
  }
}
