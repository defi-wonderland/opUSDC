// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import {ECDSA} from '@openzeppelin/contracts/utils/cryptography/ECDSA.sol';
import {MessageHashUtils} from '@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol';
import {SignatureChecker} from '@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol';
import {OpUSDCBridgeAdapter} from 'contracts/universal/OpUSDCBridgeAdapter.sol';
import {BytecodeDeployer} from 'contracts/utils/BytecodeDeployer.sol';
import {IL2OpUSDCBridgeAdapter} from 'interfaces/IL2OpUSDCBridgeAdapter.sol';
import {IL2OpUSDCFactory} from 'interfaces/IL2OpUSDCFactory.sol';
import {ICrossDomainMessenger} from 'interfaces/external/ICrossDomainMessenger.sol';
import {IUSDC} from 'interfaces/external/IUSDC.sol';

contract L2OpUSDCBridgeAdapter is IL2OpUSDCBridgeAdapter, Initializable, OpUSDCBridgeAdapter, UUPSUpgradeable {
  using ECDSA for bytes32;
  using MessageHashUtils for bytes32;
  using SignatureChecker for address;

  /// @inheritdoc IL2OpUSDCBridgeAdapter
  address public immutable MESSENGER;

  /// @inheritdoc IL2OpUSDCBridgeAdapter
  bool public isMessagingDisabled;

  /**
   * @notice Modifier to check if the sender is the linked adapter through the messenger
   */
  modifier checkSender() {
    if (msg.sender != MESSENGER || ICrossDomainMessenger(MESSENGER).xDomainMessageSender() != LINKED_ADAPTER) {
      revert IOpUSDCBridgeAdapter_InvalidSender();
    }
    _;
  }

  /**
   * @notice Construct the OpUSDCBridgeAdapter contract
   * @param _usdc The address of the USDC Contract to be used by the adapter
   * @param _messenger The address of the messenger contract
   * @param _linkedAdapter The address of the linked adapter
   * @dev The constructor is only used to initialize the OpUSDCBridgeAdapter immutable variables
   */
  /* solhint-disable no-unused-vars */
  constructor(address _usdc, address _messenger, address _linkedAdapter) OpUSDCBridgeAdapter(_usdc, _linkedAdapter) {
    MESSENGER = _messenger;
    _disableInitializers();
  }
  /* solhint-enable no-unused-vars */

  /**
   * @notice Send a message to the linked adapter to transfer the tokens to the user
   * @dev Burn the bridged representation acording to the amount sent on the message
   * @param _to The target address on the destination chain
   * @param _amount The amount of tokens to send
   * @param _minGasLimit Minimum gas limit that the message can be executed with
   */
  function sendMessage(address _to, uint256 _amount, uint32 _minGasLimit) external override {
    // Ensure messaging is enabled
    if (isMessagingDisabled) revert IOpUSDCBridgeAdapter_MessagingDisabled();

    // Burn the tokens
    IUSDC(USDC).burn(msg.sender, _amount);

    // Send the message to the linked adapter
    ICrossDomainMessenger(MESSENGER).sendMessage(
      LINKED_ADAPTER, abi.encodeWithSignature('receiveMessage(address,uint256)', _to, _amount), _minGasLimit
    );

    emit MessageSent(msg.sender, _to, _amount, MESSENGER, _minGasLimit);
  }

  /**
   * @notice Send the message to the linked adapter to mint the bridged representation on the linked chain
   * @param _signer The address of the user sending the message
   * @param _to The target address on the destination chain
   * @param _amount The amount of tokens to send
   * @param _signature The signature of the user
   * @param _deadline The deadline for the message to be executed
   * @param _minGasLimit Minimum gas limit that the message can be executed with
   */
  function sendMessage(
    address _signer,
    address _to,
    uint256 _amount,
    bytes calldata _signature,
    uint256 _deadline,
    uint32 _minGasLimit
  ) external override {
    // Ensure messaging is enabled
    if (isMessagingDisabled) revert IOpUSDCBridgeAdapter_MessagingDisabled();

    // Ensure the deadline has not passed
    if (block.timestamp > _deadline) revert IOpUSDCBridgeAdapter_MessageExpired();

    // Hash the message
    bytes32 _messageHash = keccak256(abi.encode(address(this), block.chainid, _to, _amount, userNonce[_signer]++));

    _messageHash = _messageHash.toEthSignedMessageHash();

    // Check from is the signer
    if (!_signer.isValidSignatureNow(_messageHash, _signature)) revert IOpUSDCBridgeAdapter_InvalidSignature();

    // Burn the tokens
    IUSDC(USDC).burn(_signer, _amount);

    // Send the message to the linked adapter
    ICrossDomainMessenger(MESSENGER).sendMessage(
      LINKED_ADAPTER, abi.encodeWithSignature('receiveMessage(address,uint256)', _to, _amount), _minGasLimit
    );

    emit MessageSent(_signer, _to, _amount, MESSENGER, _minGasLimit);
  }

  /**
   * @notice Receive the message from the other chain and mint the bridged representation for the user
   * @dev This function should only be called when receiving a message to mint the bridged representation
   * @param _user The user to mint the bridged representation for
   * @param _amount The amount of tokens to mint
   */
  function receiveMessage(address _user, uint256 _amount) external override checkSender {
    // Mint the tokens to the user
    IUSDC(USDC).mint(_user, _amount);
    emit MessageReceived(_user, _amount, MESSENGER);
  }

  /**
   * @notice Receive the stop messaging message from the linked adapter and stop outgoing messages
   */
  function receiveStopMessaging() external checkSender {
    isMessagingDisabled = true;

    emit MessagingStopped(MESSENGER);
  }

  /**
   * @notice Resume messaging after it was stopped
   */
  function receiveResumeMessaging() external checkSender {
    // NOTE: This is safe because this message can only be received when messaging is not deprecated on the L1 messenger
    isMessagingDisabled = false;

    emit MessagingResumed(MESSENGER);
  }

  /**
   * @notice Receive the creation code from the linked adapter, deploy the new implementation and upgrade
   * @param _l2AdapterBytecode The bytecode for the new L2 adapter implementation
   * @param _l2AdapterInitTxs The initialization transactions for the new L2 adapter implementation
   */
  function receiveAdapterUpgrade(
    bytes calldata _l2AdapterBytecode,
    bytes[] calldata _l2AdapterInitTxs
  ) external checkSender {
    // Deploy L2 adapter implementation
    address _adapterImplementation;
    bytes memory _bytecode = abi.encodePacked(_l2AdapterBytecode, abi.encode(USDC, MESSENGER, LINKED_ADAPTER));
    assembly {
      _adapterImplementation := create(0, add(_bytecode, 0x20), mload(_bytecode))
      if iszero(extcodesize(_adapterImplementation)) { revert(0, 0) }
    }
    // address _adapterImplementation = address(new BytecodeDeployer(_bytecode));
    emit IL2OpUSDCFactory.DeployedL2AdapterImplementation(_adapterImplementation);

    //Upgrade to the new implementation
    upgradeToAndCall(_adapterImplementation, '');

    // // Cache intialization transactions length
    // uint256 _l2AdapterInitTxsLength = _l2AdapterInitTxs.length;

    // //Execute the initialization transactions
    // if (_l2AdapterInitTxsLength > 1) {
    //   // Initialize L2 adapter
    //   for (uint256 i = 1; i < _l2AdapterInitTxsLength; i++) {
    //     (bool _success,) = address(this).call(_l2AdapterInitTxs[i]);
    //     if (!_success) {
    //       revert L2OpUSDCBridgeAdapter_AdapterInitializationFailed();
    //     }
    //   }
    // }
  }

  /**
   * @notice Authorize the upgrade of the implementation of the contract
   * @param _newImplementation The address of the new implementation
   */
  function _authorizeUpgrade(address _newImplementation) internal override checkSender {}
}
