// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {L1OpUSDCBridgeAdapter} from 'contracts/L1OpUSDCBridgeAdapter.sol';
import {L2OpUSDCBridgeAdapter} from 'contracts/L2OpUSDCBridgeAdapter.sol';
import {IOpUSDCFactory} from 'interfaces/IOpUSDCFactory.sol';
import {ICreateX} from 'interfaces/external/ICreateX.sol';
import {ICrossDomainMessenger} from 'interfaces/external/ICrossDomainMessenger.sol';

import 'forge-std/Test.sol';

contract OpUSDCFactory is IOpUSDCFactory {
  struct DeployParams {
    ICrossDomainMessenger l2Messenger;
    bytes l1OpUSDCBridgeAdapterCreationCode;
    bytes l2OpUSDCBridgeAdapterCreationCode;
    bytes usdcProxyCreationCode;
    bytes usdcImplementationCreationCode;
    address owner;
    uint32 minGasLimitUsdcProxyDeploy;
    uint32 minGasLimitUsdcImplementationDeploy;
    uint32 minGasLimitL2AdapterDeploy;
    uint32 minGasLimitInitializeTxs;
    uint256 l2ChainId;
  }

  address public constant ADDRESS_ONE = address(1);
  bytes public constant INITIALIZE_TX = abi.encodeWithSignature(
    'initialize(string,string,string,uint8,address,address,address,address)',
    '',
    '',
    '',
    0,
    ADDRESS_ONE,
    ADDRESS_ONE,
    ADDRESS_ONE,
    ADDRESS_ONE
  );
  bytes public constant INITIALIZE2_TX = abi.encodeWithSignature('initializeV2(string)', '');
  bytes public constant INITIALIZE2_1_TX = abi.encodeWithSignature('initializeV2_1(address)', ADDRESS_ONE);
  bytes public constant INITIALIZE2_2_TX =
    abi.encodeWithSignature('initializeV2_2(address[],string)', new address[](0), '');
  bytes public constant PROXY_CHILD_BYTECODE = hex'67363d3d37363d34f03d5260086018f3';

  bytes32 public immutable SALT;
  bytes32 public immutable GUARDED_SALT_L1;
  address public immutable PROXY_DEPLOYER;
  address public immutable L1_LINKED_ADAPTER;
  ICrossDomainMessenger public immutable L1_CROSS_DOMAIN_MESSENGER;
  address public immutable USDC;
  address public immutable USDC_IMPLEMENTATION;
  ICreateX public immutable L1_CREATEX;
  address public immutable L2_CREATEX;

  constructor(
    ICrossDomainMessenger _l1Messenger,
    address _usdc,
    address _usdcImplementation,
    ICreateX _createXL1,
    address _createXL2,
    uint256 _salt
  ) {
    L1_CROSS_DOMAIN_MESSENGER = _l1Messenger;
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
    GUARDED_SALT_L1 = keccak256(abi.encode(address(this), block.chainid, SALT));
    // PROXY_DEPLOYER = ICreateX(L1_CREATEX).computeCreate2Address(GUARDED_SALT_L1, keccak256(PROXY_CHILD_BYTECODE));
    // Calculate L1 adapter address
    L1_LINKED_ADAPTER = L1_CREATEX.computeCreate3Address(GUARDED_SALT_L1, address(L1_CREATEX));
  }

  function deploy(DeployParams memory _params) external {
    // Declare vars and define them in a block to avoid stack too deep error to get the L2 deployment addresses and txs
    address _l2LinkedAdapter;
    address _l2UsdcImplementation;
    bytes memory _usdcImplementationDeployTx;
    bytes memory _usdcDeployProxyTx;
    bytes memory _l2AdapterDeployTx;

    {
      bytes32 _messengerToBytes = bytes32(uint256(uint160(address(_params.l2Messenger))) << 96);
      bytes32 crossChainByte = bytes32(uint256(0x01) << (88));
      // Mask the given salt to take only the last 12 bytes and prevent it from interfering with the address part
      bytes32 _parsedSalt = bytes32(uint256(SALT) & 0x000000000000000000000000000000000000000000ffffffffffffffffffff);
      bytes32 _saltTwo = _messengerToBytes | crossChainByte | _parsedSalt;
      bytes32 _guardedSaltL2 = keccak256(abi.encode(_params.l2Messenger, _params.l2ChainId, _saltTwo));
      console.log('_guardedSaltL2: %s');
      console.logBytes32(_guardedSaltL2);

      // Deploy usdc implementation on l2 tx
      _usdcImplementationDeployTx =
        abi.encodeWithSignature('deployCreate2(bytes32,bytes)', _saltTwo, _params.usdcImplementationCreationCode);
      // Precalculate usdc implementation address on l2
      _l2UsdcImplementation = L1_CREATEX.computeCreate2Address(
        _guardedSaltL2, keccak256(_params.usdcImplementationCreationCode), address(L2_CREATEX)
      );

      // Deploy usdc on L2 tx
      bytes memory _usdcInitCode = bytes.concat(_params.usdcProxyCreationCode, abi.encode(_l2UsdcImplementation));
      _usdcDeployProxyTx = abi.encodeWithSignature('deployCreate2(bytes32,bytes)', _saltTwo, _usdcInitCode);
      // Precalculate token address on l2
      address _l2Usdc = L1_CREATEX.computeCreate2Address(_guardedSaltL2, keccak256(_usdcInitCode), L2_CREATEX);

      // Deploy adapter on L2 tx
      bytes memory _l2AdapterCArgs = abi.encode(_l2Usdc, _params.l2Messenger, L1_LINKED_ADAPTER);
      bytes memory _l2AdapterInitCode = bytes.concat(_params.l2OpUSDCBridgeAdapterCreationCode, _l2AdapterCArgs);
      _l2AdapterDeployTx = abi.encodeWithSignature('deployCreate2(bytes32,bytes)', _saltTwo, _l2AdapterInitCode);
      // Precalculate linked adapter address on L2
      _l2LinkedAdapter = L1_CREATEX.computeCreate2Address(_guardedSaltL2, keccak256(_l2AdapterInitCode), L2_CREATEX);

      console.log('_l2Usdc: %s', _l2Usdc);
    }

    console.log('_l2UsdcImplementation: %s', _l2UsdcImplementation);
    console.log('_l2LinkedAdapter: %s', _l2LinkedAdapter);

    // Send the usdc and adapter deploy messages to L2
    L1_CROSS_DOMAIN_MESSENGER.sendMessage(
      L2_CREATEX, _usdcImplementationDeployTx, _params.minGasLimitUsdcImplementationDeploy
    );
    L1_CROSS_DOMAIN_MESSENGER.sendMessage(_l2UsdcImplementation, INITIALIZE_TX, _params.minGasLimitInitializeTxs);
    L1_CROSS_DOMAIN_MESSENGER.sendMessage(_l2UsdcImplementation, INITIALIZE2_TX, _params.minGasLimitInitializeTxs);
    L1_CROSS_DOMAIN_MESSENGER.sendMessage(_l2UsdcImplementation, INITIALIZE2_1_TX, _params.minGasLimitInitializeTxs);
    L1_CROSS_DOMAIN_MESSENGER.sendMessage(_l2UsdcImplementation, INITIALIZE2_2_TX, _params.minGasLimitInitializeTxs);
    L1_CROSS_DOMAIN_MESSENGER.sendMessage(L2_CREATEX, _usdcDeployProxyTx, _params.minGasLimitUsdcProxyDeploy);
    L1_CROSS_DOMAIN_MESSENGER.sendMessage(L2_CREATEX, _l2AdapterDeployTx, _params.minGasLimitL2AdapterDeploy);

    /* Deploy the L1 adapter */
    // Breaking the CEI here because the deployment is way more expensive than sending the messages if they revert
    address _createdL1Adapter = L1_CREATEX.deployCreate3(
      SALT,
      bytes.concat(
        _params.l1OpUSDCBridgeAdapterCreationCode,
        abi.encode(USDC, address(L1_CROSS_DOMAIN_MESSENGER), _l2LinkedAdapter, _params.owner)
      )
    );

    console.log('COMPUTED L1_LINKED_ADAPTER: %s', L1_LINKED_ADAPTER);
    console.log('CREATED L1 ADAPTER: %s', _createdL1Adapter);
  }
}
