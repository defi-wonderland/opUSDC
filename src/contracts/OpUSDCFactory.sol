// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {CreateX} from 'contracts/CreateX.sol';
import {L1OpUSDCBridgeAdapter} from 'contracts/L1OpUSDCBridgeAdapter.sol';
import {L2OpUSDCBridgeAdapter} from 'contracts/L2OpUSDCBridgeAdapter.sol';
import {AddressAliasHelper} from 'contracts/utils/AddressAliasHelper.sol';
import {IOpUSDCFactory} from 'interfaces/IOpUSDCFactory.sol';
import {ICreateX} from 'interfaces/external/ICreateX.sol';
import {ICrossDomainMessenger} from 'interfaces/external/ICrossDomainMessenger.sol';
import {IOptimismPortal} from 'interfaces/external/IOptimismPortal.sol';

contract OpUSDCFactory is IOpUSDCFactory {
  bytes32 public immutable SALT;
  ICrossDomainMessenger public immutable L1_CROSS_DOMAIN_MESSENGER;
  ICrossDomainMessenger public immutable L2_CROSS_DOMAIN_MESSENGER;
  address public immutable USDC;
  address public immutable USDC_IMPLEMENTATION;
  ICreateX public immutable L1_CREATEX;
  address public immutable L2_CREATEX;

  constructor(
    ICrossDomainMessenger _l1Messenger,
    ICrossDomainMessenger _l2Messenger,
    address _usdc,
    address _usdcImplementation,
    ICreateX _createXL1,
    address _createXL2,
    uint256 _salt
  ) {
    L1_CROSS_DOMAIN_MESSENGER = _l1Messenger;
    L2_CROSS_DOMAIN_MESSENGER = _l2Messenger;
    // TODO: Checks for usdc/usdc impl ??
    USDC = _usdc;
    USDC_IMPLEMENTATION = _usdcImplementation;
    L1_CREATEX = _createXL1;
    L2_CREATEX = _createXL2;

    // Tamper the salts with the address of the contract
    bytes32 _addressThisToBytes = bytes32(uint256(uint160(address(this))) << 96);
    bytes32 crossChainByte = bytes32(uint256(0x01) << (88));
    // Mask the given salt to take only the last 12 bytes and prevent it from interfering with the address part
    bytes32 _parsedSalt = bytes32(_salt + 1 & 0x000000000000000000000000000000000000000000ffffffffffffffffffff);
    SALT = _addressThisToBytes | crossChainByte | _parsedSalt;
  }

  function deploy(
    bytes memory _usdcCreationCode,
    uint32 _minGasLimitUsdcDeploy,
    uint32 _minGasLimitAdapterDeploy
  ) external {
    // Get the proxy address created on the `deployAndCreate3` thath will deploy the adapter
    bytes memory proxyChildBytecode = hex'67363d3d37363d34f03d5260086018f3';
    bytes32 _guardedSalt = keccak256(abi.encode(address(this), block.chainid, SALT));
    address _proxyDeployer = ICreateX(L1_CREATEX).computeCreate2Address(_guardedSalt, keccak256(proxyChildBytecode));

    // Calculate L1 adapter address
    address _l1LinkedAdapter = L1_CREATEX.computeCreate3Address(SALT, _proxyDeployer);

    // Declare vars and define them in a block to avoid stack too deep error
    address _l2LinkedAdapter;
    bytes memory _usdcDeployAndInitTx;
    bytes memory _adapterDeployTx;
    {
      // Precalculate token address on l2
      bytes memory _usdcInitCode = bytes.concat(_usdcCreationCode, abi.encode(USDC_IMPLEMENTATION));
      address _l2Usdc = L1_CREATEX.computeCreate2Address(SALT, keccak256(_usdcInitCode), L2_CREATEX);

      // If the deployer is an EOA, we transfer the ownership of the USDC to the same address. Otherwise, we transfer it
      // to the aliased contract.
      // TODO: could we use `tx.origin` here instead of the aliased sender in case there it is a contract?
      address _l2ChainOperator =
        address(msg.sender).code.length == 0 ? msg.sender : AddressAliasHelper.applyL1ToL2Alias(msg.sender);
      bytes memory _transferOwnershipTx = abi.encodeWithSelector(Ownable.transferOwnership.selector, _l2ChainOperator);

      // Deploy Token on L2 and transfer ownership as initial tx
      ICreateX.Values memory _noConstructorValues = ICreateX.Values(0, 0);
      _usdcDeployAndInitTx = abi.encodeWithSignature(
        'deployCreate2AndInit(bytes32,bytes,bytes,bytes)',
        SALT,
        _usdcInitCode,
        _transferOwnershipTx,
        _noConstructorValues
      );

      // Deploy adapter on L2 tx
      bytes memory _l2AdapterCArgs = abi.encode(_l2Usdc, L2_CROSS_DOMAIN_MESSENGER, _l1LinkedAdapter);
      bytes memory _l2AdapterInitCode = bytes.concat(type(L2OpUSDCBridgeAdapter).creationCode, _l2AdapterCArgs);
      _adapterDeployTx = abi.encodeWithSignature('deployCreate2(bytes32,bytes)', SALT, _l2AdapterInitCode);
      // Precalculate linked adapter address on L2
      _l2LinkedAdapter = L1_CREATEX.computeCreate2Address(SALT, keccak256(_l2AdapterInitCode), L2_CREATEX);
    }

    // Send the usdc and adapter deploy messages to L2
    L1_CROSS_DOMAIN_MESSENGER.sendMessage(L2_CREATEX, _usdcDeployAndInitTx, _minGasLimitUsdcDeploy);
    L1_CROSS_DOMAIN_MESSENGER.sendMessage(L2_CREATEX, _adapterDeployTx, _minGasLimitAdapterDeploy);

    /* Deploy the L1 adapter */
    // Breaking the CEI here because the deployment is way more expensive than sending the messages if they revert
    L1_CREATEX.deployCreate3(
      SALT,
      bytes.concat(
        type(L1OpUSDCBridgeAdapter).creationCode,
        abi.encode(USDC, address(L1_CROSS_DOMAIN_MESSENGER), _l2LinkedAdapter, msg.sender)
      )
    );
  }
}
