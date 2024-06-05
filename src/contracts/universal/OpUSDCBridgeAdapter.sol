// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {MessageHashUtils} from '@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol';
import {SignatureChecker} from '@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol';
import {IOpUSDCBridgeAdapter} from 'interfaces/IOpUSDCBridgeAdapter.sol';
import {ICrossDomainMessenger} from 'interfaces/external/ICrossDomainMessenger.sol';

abstract contract OpUSDCBridgeAdapter is IOpUSDCBridgeAdapter {
  using MessageHashUtils for bytes32;
  using SignatureChecker for address;

  /// @inheritdoc IOpUSDCBridgeAdapter
  address public immutable USDC;

  /// @inheritdoc IOpUSDCBridgeAdapter
  address public immutable LINKED_ADAPTER;

  /// @inheritdoc IOpUSDCBridgeAdapter
  mapping(address _user => uint256 _nonce) public userNonce;

  /**
   * @notice Construct the OpUSDCBridgeAdapter contract
   * @param _usdc The address of the USDC Contract to be used by the adapter
   * @param _linkedAdapter The address of the linked adapter
   */
  constructor(address _usdc, address _linkedAdapter) {
    USDC = _usdc;
    LINKED_ADAPTER = _linkedAdapter;
  }

  /**
   * @notice Receive the message from the other chain and mint the bridged representation for the user
   * @dev This function should only be called when receiving a message to mint the bridged representation
   * @param _user The user to mint the bridged representation for
   * @param _amount The amount of tokens to mint
   */
  function receiveMessage(address _user, uint256 _amount) external virtual;

  /**
   * @notice Send a message to the other chain
   * @param _messenger The address of the messenger contract
   * @param _target The address of the target contract on the other chain
   * @param _message The message to send
   * @param _minGasLimit The minimum gas limit for the message
   */
  function _xDomainMessage(address _messenger, address _target, bytes memory _message, uint32 _minGasLimit) internal {
    ICrossDomainMessenger(_messenger).sendMessage(_target, _message, _minGasLimit);
  }

  /**
   * @notice Returns the sender of the message from the other chain
   * @param _messenger The address of the messenger contract on the current chain
   * @return _sender The address of the sender of the message from the other chain
   */
  function _xDomainMessageSender(address _messenger) internal view returns (address _sender) {
    _sender = ICrossDomainMessenger(_messenger).xDomainMessageSender();
  }

  /**
   * @notice Check the signature of a message
   * @param _signer the address that signed the message
   * @param _messageHash the hash of the message that was signed
   * @param _signature the signature of the message
   */
  function _checkSignature(address _signer, bytes32 _messageHash, bytes memory _signature) internal view {
    _messageHash = _messageHash.toEthSignedMessageHash();

    if (!_signer.isValidSignatureNow(_messageHash, _signature)) revert IOpUSDCBridgeAdapter_InvalidSignature();
  }
}
