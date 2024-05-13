// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {CreateX} from 'contracts/CreateX.sol';
import {L1OpUSDCBridgeAdapter} from 'contracts/L1OpUSDCBridgeAdapter.sol';
import {L2OpUSDCBridgeAdapter} from 'contracts/L2OpUSDCBridgeAdapter.sol';
import {AddressAliasHelper} from 'contracts/utils/AddressAliasHelper.sol';
import {IOpUSDCFactory} from 'interfaces/IOpUSDCFactory.sol';
import {ICreateX} from 'interfaces/external/ICreateX.sol';
import {ICrossDomainMessenger} from 'interfaces/external/ICrossDomainMessenger.sol';
import {IOptimismPortal} from 'interfaces/external/IOptimismPortal.sol';
import {IUSDC} from 'interfaces/external/IUSDC.sol';

// NOTE: Possible grieffing attack where someone already deploys the contract on the same address before the message
// arrives to L2. solution -> ** deploy create3 on L1 and create2 on L2 **

// TODO: What happens on the chains where CREATEX is not deployed? -> They need to have it. Otherwise we can use a CREATE3 lib.

contract OpUSDCFactory is IOpUSDCFactory {
  // TODO: What salts to use?
  bytes32 public constant SALT_ONE = 0x0000000000000000000000000000000000000000000000000000000000000001;
  bytes32 public constant SALT_TWO = 0x0000000000000000000000000000000000000000000000000000000000000002;
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
    address _createxL2
  ) {
    L1_CROSS_DOMAIN_MESSENGER = _l1Messenger;
    USDC = _usdc;
    USDC_IMPLEMENTATION = _usdcImplementation;
    L1_CREATEX = _createXL1;
    L2_CREATEX = _createxL2;
  }

  function deploy(
    bytes memory _l2AdapterCode,
    uint32 _minGasLimitUsdcDeploy,
    uint32 _minGasLimitAdapterDeploy
  ) external {
    // Send a message using createX to deploy:
    // address deployer = AddressAliasHelper.applyL1ToL2Alias(L2_CREATEX);

    //  Calculate L1 adapter address
    address _l1AdapterAddress = L1_CREATEX.computeCreate3Address(SALT_ONE, address(this));

    // TODO: sanitiy checks for usdc/usdc impl
    // if (_usdcImplementation) {}

    // Precalculate token address on l2
    // bytes memory _usdcCode = USDC.code;
    // bytes memory _usdcCArgs = abi.encode(_usdcImplementation);
    bytes32 _usdcInitCodeHash = keccak256(abi.encode(USDC.code, abi.encode(USDC_IMPLEMENTATION)));
    address _l2Usdc = L1_CREATEX.computeCreate2Address(SALT_ONE, _usdcInitCodeHash, address(this));

    // Precalculate address on L2
    bytes memory _l2AdapterCArgs = abi.encode(USDC, L1_CROSS_DOMAIN_MESSENGER, _l1AdapterAddress);
    bytes32 _l2AdapterCodeHash = keccak256(abi.encode(_l2AdapterCode, _l2AdapterCArgs));
    address _l2LinkedAdapter = L1_CREATEX.computeCreate2Address(SALT_TWO, _l2AdapterCodeHash, address(this));

    // Deploy Token on L2
    ICreateX.Values memory _constructorValues = ICreateX.Values(0, 0);
    bytes memory _usdcDeployTx = abi.encodeWithSignature(
      'deployCreate2AndInit(bytes32,bytes,bytes,bytes)',
      SALT_ONE,
      _usdcInitCodeHash,
      USDC.code,
      abi.encode(USDC_IMPLEMENTATION.code),
      _constructorValues
    );

    // Deploy adapter on L2 tx
    // bytes memory _adapterConstructorData = abi.encode(_l2Usdc, L1_CROSS_DOMAIN_MESSENGER, _l2LinkedAdapter);
    bytes memory _adapterDeployTx = abi.encodeWithSignature(
      'deployCreate2AndInit(bytes32,bytes,bytes,bytes)',
      SALT_TWO,
      _l2AdapterCodeHash,
      _l2AdapterCode,
      abi.encode(_l2Usdc, L1_CROSS_DOMAIN_MESSENGER, _l2LinkedAdapter),
      _constructorValues
    );

    // Send the deploy messages to L2
    L1_CROSS_DOMAIN_MESSENGER.sendMessage(L2_CREATEX, _usdcDeployTx, _minGasLimitUsdcDeploy);
    L1_CROSS_DOMAIN_MESSENGER.sendMessage(L2_CREATEX, _adapterDeployTx, _minGasLimitAdapterDeploy);

    // Breaking the CEI here because I think the deployment is way more expensive than sending the messages in case they revert
    // Deploy L1 adapter
    bytes memory _l1LinkedadapterCode = type(L1OpUSDCBridgeAdapter).creationCode;
    L1_CREATEX.deployCreate3AndInit(
      SALT_ONE, _l1LinkedadapterCode, abi.encode(USDC, L1_CROSS_DOMAIN_MESSENGER, _l2LinkedAdapter), _constructorValues
    );
  }
}

// TODO: What happens if the message is not successful on L2?
// Should we add a retry messages function? -> Maybe having a single `deploy()` function and 2 internals for
// the deploy of the USDC and the adapter, jic if the L2 side fails we can retry the message only executing that.

// TODO: Is there a way to get the L1 USDC implementation from the L1 proxy? Seems there's not
