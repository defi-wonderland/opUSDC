// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {USDCInitTxs} from 'contracts/utils/USDCInitTxs.sol';
import {IOpUSDCFactory} from 'interfaces/IOpUSDCFactory.sol';
import {ICreateX} from 'interfaces/external/ICreateX.sol';
import {ICrossDomainMessenger} from 'interfaces/external/ICrossDomainMessenger.sol';

contract OpUSDCFactory is IOpUSDCFactory {
  /**
   * @inheritdoc IOpUSDCFactory
   */
  bytes32 public immutable SALT;

  /**
   * @inheritdoc IOpUSDCFactory
   */
  address public immutable L1_LINKED_ADAPTER;

  /**
   * @inheritdoc IOpUSDCFactory
   */
  ICrossDomainMessenger public immutable L1_CROSS_DOMAIN_MESSENGER;

  /**
   * @inheritdoc IOpUSDCFactory
   */
  address public immutable USDC;

  /**
   * @inheritdoc IOpUSDCFactory
   */
  ICreateX public immutable L1_CREATEX;

  /**
   * @inheritdoc IOpUSDCFactory
   */
  address public immutable L2_CREATEX;

  /**
   * @param _l1Messenger The CrossDomainMessenger contract on L1
   * @param _usdc The address of the USDC contract
   * @param _createXL1 The CreateX contract on L1
   * @param _createXL2 The address of the CreateX contract on L2
   * @param _salt The random value to be used when calculating the salt for the factory deployment
   */
  constructor(
    ICrossDomainMessenger _l1Messenger,
    address _usdc,
    ICreateX _createXL1,
    address _createXL2,
    uint256 _salt
  ) {
    L1_CROSS_DOMAIN_MESSENGER = _l1Messenger;
    USDC = _usdc;
    L1_CREATEX = _createXL1;
    L2_CREATEX = _createXL2;

    // Tamper the salts with the address of the contract
    bytes32 _addressThisToBytes = bytes32(uint256(uint160(address(this))) << 96);
    bytes32 crossChainByte = bytes32(uint256(0x01) << (88));
    // Mask the given salt to take only the last 12 bytes and prevent it from interfering with the address part
    bytes32 _parsedSalt = bytes32(_salt + 1 & 0x000000000000000000000000000000000000000000ffffffffffffffffffff);
    SALT = _addressThisToBytes | crossChainByte | _parsedSalt;
    bytes32 _guardedSaltL1 = keccak256(abi.encode(address(this), block.chainid, SALT));
    // Calculate L1 adapter address
    L1_LINKED_ADAPTER = L1_CREATEX.computeCreate3Address(_guardedSaltL1, address(L1_CREATEX));
  }

  /**
   * @inheritdoc IOpUSDCFactory
   */
  function deploy(DeployParams memory _params) external {
    // Declare vars and define them in a block to avoid stack too deep error to get the L2 deployment addresses and txs
    address _l2LinkedAdapter;
    address _l2UsdcImplementation;
    bytes memory _usdcImplementationDeployTx;
    bytes memory _usdcDeployProxyTx;
    bytes memory _l2AdapterDeployTx;

    {
      bytes32 _messengerToBytes = bytes32(uint256(uint160(_params.l2Messenger)) << 96);
      bytes32 crossChainByte = bytes32(uint256(0x01) << (88));
      // Mask the given salt to take only the last 12 bytes and prevent it from interfering with the address part
      bytes32 _parsedSalt = bytes32(uint256(SALT) & 0x000000000000000000000000000000000000000000ffffffffffffffffffff);
      bytes32 _saltTwo = _messengerToBytes | crossChainByte | _parsedSalt;
      bytes32 _guardedSaltL2 = keccak256(abi.encode(_params.l2Messenger, _params.l2ChainId, _saltTwo));

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
    }

    // Send the usdc and adapter deploy messages to L2
    L1_CROSS_DOMAIN_MESSENGER.sendMessage(
      L2_CREATEX, _usdcImplementationDeployTx, _params.minGasLimitUsdcImplementationDeploy
    );
    L1_CROSS_DOMAIN_MESSENGER.sendMessage(
      _l2UsdcImplementation, USDCInitTxs.INITIALIZE, _params.minGasLimitInitializeTxs
    );
    L1_CROSS_DOMAIN_MESSENGER.sendMessage(
      _l2UsdcImplementation, USDCInitTxs.INITIALIZEV2, _params.minGasLimitInitializeTxs
    );
    L1_CROSS_DOMAIN_MESSENGER.sendMessage(
      _l2UsdcImplementation, USDCInitTxs.INITIALIZEV2_1, _params.minGasLimitInitializeTxs
    );
    L1_CROSS_DOMAIN_MESSENGER.sendMessage(
      _l2UsdcImplementation, USDCInitTxs.INITIALIZEV2_2, _params.minGasLimitInitializeTxs
    );
    L1_CROSS_DOMAIN_MESSENGER.sendMessage(L2_CREATEX, _usdcDeployProxyTx, _params.minGasLimitUsdcProxyDeploy);
    L1_CROSS_DOMAIN_MESSENGER.sendMessage(L2_CREATEX, _l2AdapterDeployTx, _params.minGasLimitL2AdapterDeploy);

    // Deploy the L1 adapter
    L1_CREATEX.deployCreate3(
      SALT,
      bytes.concat(
        _params.l1OpUSDCBridgeAdapterCreationCode,
        abi.encode(USDC, address(L1_CROSS_DOMAIN_MESSENGER), _l2LinkedAdapter, _params.owner)
      )
    );
  }
}
