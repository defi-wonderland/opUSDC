// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {CreateX} from 'contracts/CreateX.sol';
import {L1OpUSDCBridgeAdapter} from 'contracts/L1OpUSDCBridgeAdapter.sol';
import {L2OpUSDCBridgeAdapter} from 'contracts/L2OpUSDCBridgeAdapter.sol';
import {AddressAliasHelper} from 'contracts/utils/AddressAliasHelper.sol';
import {USDC_CREATION_CODE} from 'contracts/utils/USDCCreationCode.sol';
import {IOpUSDCFactory} from 'interfaces/IOpUSDCFactory.sol';
import {ICreateX} from 'interfaces/external/ICreateX.sol';
import {ICrossDomainMessenger} from 'interfaces/external/ICrossDomainMessenger.sol';
import {IOptimismPortal} from 'interfaces/external/IOptimismPortal.sol';

contract OpUSDCFactory is IOpUSDCFactory {
  using AddressAliasHelper for bytes;

  bytes32 public immutable SALT_ONE;
  bytes32 public immutable SALT_TWO;
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
    address _createXL2
  ) {
    L1_CROSS_DOMAIN_MESSENGER = _l1Messenger;
    L2_CROSS_DOMAIN_MESSENGER = _l2Messenger;
    // TODO: sanitiy checks for usdc/usdc impl ??
    USDC = _usdc;
    USDC_IMPLEMENTATION = _usdcImplementation;
    L1_CREATEX = _createXL1;
    L2_CREATEX = _createXL2;
    // Tamper the salts with the address of the contract
    bytes32 _addressThisToBytes = bytes32(uint256(uint160(address(this))) << 96);
    bytes32 _randomSaltOne = bytes32(abi.encodePacked(_addressThisToBytes)) & bytes32('0xFFFFFFFFFFFFFFFFFFFFFFFF');
    SALT_ONE = _addressThisToBytes | _randomSaltOne;
    bytes32 _randomSaltTwo = bytes32(abi.encodePacked(_addressThisToBytes)) & bytes32('0xEEEEEEEEEEEEEEEEEEEEEEEE');
    SALT_TWO = _addressThisToBytes | _randomSaltTwo;
  }

  function deploy(uint32 _minGasLimitUsdcDeploy, uint32 _minGasLimitAdapterDeploy) external {
    // TODO: Properly calculate the deployer
    address deployer = 0xBb01593481E3a7f49981a0ccaB847E3be0B367ee; // Create3 proxy address

    //  Calculate L1 adapter address
    address _l1LinkedAdapter = L1_CREATEX.computeCreate3Address(SALT_ONE, deployer);

    // Declare vars and define them in a block to avoid stack too deep error
    address _l2LinkedAdapter;
    bytes memory _usdcDeployAndInitTx;
    bytes memory _adapterDeployTx;
    {
      // Precalculate token address on l2
      bytes memory _usdcInitCode = bytes.concat(USDC_CREATION_CODE, abi.encode(USDC_IMPLEMENTATION));
      address _l2Usdc = L1_CREATEX.computeCreate2Address(SALT_ONE, keccak256(_usdcInitCode), deployer);

      // If the deployer is an EOA, we transfer the ownership of the USDC to the same address. Otherwise, we transfer it
      // to the aliased contract.
      address _l2ChainOperator =
        address(msg.sender).code.length == 0 ? address(this) : AddressAliasHelper.applyL1ToL2Alias(msg.sender);
      bytes memory _transferOwnershipTx = abi.encodeWithSelector(Ownable.transferOwnership.selector, _l2ChainOperator);

      // Deploy Token on L2 and transfer ownership as initial tx
      ICreateX.Values memory _noConstructorValues = ICreateX.Values(0, 0);
      _usdcDeployAndInitTx = abi.encodeWithSignature(
        'deployCreate2AndInit(bytes32,bytes,bytes,bytes)',
        SALT_ONE,
        _usdcInitCode,
        _transferOwnershipTx,
        _noConstructorValues
      );

      // Precalculate linked adapter address on L2
      // bytes memory _l2AdapterCArgs = abi.encode(USDC, L2_CROSS_DOMAIN_MESSENGER, _l1LinkedAdapter);
      bytes memory _l2AdapterInitCode = bytes.concat(
        type(L2OpUSDCBridgeAdapter).creationCode, abi.encode(_l2Usdc, L2_CROSS_DOMAIN_MESSENGER, _l1LinkedAdapter)
      );
      _l2LinkedAdapter = L1_CREATEX.computeCreate2Address(SALT_TWO, keccak256(_l2AdapterInitCode), deployer);

      // Deploy adapter on L2 tx
      // bytes memory _adapterConstructorData = abi.encode(_l2Usdc, L1_CROSS_DOMAIN_MESSENGER, _l2LinkedAdapter);
      _adapterDeployTx = abi.encodeWithSignature('deployCreate2AndInit(bytes32,bytes)', SALT_TWO, _l2AdapterInitCode);
    }

    // Send the deploy messages to L2
    L1_CROSS_DOMAIN_MESSENGER.sendMessage(L2_CREATEX, _usdcDeployAndInitTx, _minGasLimitUsdcDeploy);
    L1_CROSS_DOMAIN_MESSENGER.sendMessage(L2_CREATEX, _adapterDeployTx, _minGasLimitAdapterDeploy);

    /* Deploy the L1 adapter */
    // Breaking the CEI here because the deployment is way more expensive than sending the messages if they revert
    L1_CREATEX.deployCreate3(
      SALT_ONE,
      bytes.concat(
        type(L1OpUSDCBridgeAdapter).creationCode,
        abi.encode(USDC, address(L1_CROSS_DOMAIN_MESSENGER), _l2LinkedAdapter, msg.sender)
      )
    );
  }
}

// NOTE: Possible grieffing attack where someone already deploys the contract on the same address before the message
// arrives to L2. solution -> ** deploy create3 on L1 and create2 on L2 **

// TODO: What happens on the chains where CREATEX is not deployed? -> They need to have it. Otherwise we can use a CREATE3 lib.

// TODO: What happens if the message is not successful on L2?
// Should we add a retry messages function? -> Maybe having a single `deploy()` function and 2 internals for
// the deploy of the USDC and the adapter, jic if the L2 side fails we can retry the message only executing that.

// TODO: Is there a way to get the L1 USDC implementation from the L1 proxy? Seems there's not

// TODO: Currently the adapter codes are get from the interface. If they are set to be upgradeable, the best option is
// receive their code as arguments.

// TODO: Could we have the USDC proxy creation code?
