// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import {MessageHashUtils} from '@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol';
import {SignatureChecker} from '@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol';
import {IOpUSDCBridgeAdapter} from 'interfaces/IOpUSDCBridgeAdapter.sol';

abstract contract OpUSDCBridgeAdapter is IOpUSDCBridgeAdapter, UUPSUpgradeable {
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
