// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {MessageHashUtils} from '@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol';
import {SignatureChecker} from '@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol';
import {IOpUSDCBridgeAdapter} from 'interfaces/IOpUSDCBridgeAdapter.sol';

abstract contract OpUSDCBridgeAdapter is IOpUSDCBridgeAdapter, Ownable {
  using MessageHashUtils for bytes32;
  using SignatureChecker for address;

  /// @inheritdoc IOpUSDCBridgeAdapter
  address public immutable USDC;

  /// @inheritdoc IOpUSDCBridgeAdapter
  address public immutable LINKED_ADAPTER;

  /// @inheritdoc IOpUSDCBridgeAdapter
  address public immutable MESSENGER;

  /// @inheritdoc IOpUSDCBridgeAdapter
  Status public messengerStatus;

  /// @inheritdoc IOpUSDCBridgeAdapter
  mapping(address _user => mapping(uint256 _nonce => bool _used)) public userNonces;

  /// @inheritdoc IOpUSDCBridgeAdapter
  mapping(address _user => uint256 _blacklistedAmount) public userBlacklistedFunds;

  /**
   * @notice Construct the OpUSDCBridgeAdapter contract
   * @param _usdc The address of the USDC Contract to be used by the adapter
   * @param _messenger The address of the messenger contract
   * @param _linkedAdapter The address of the linked adapter
   * @param _owner The address of the owner of the contract
   */
  // solhint-disable-next-line no-unused-vars
  constructor(address _usdc, address _messenger, address _linkedAdapter, address _owner) Ownable(_owner) {
    USDC = _usdc;
    MESSENGER = _messenger;
    LINKED_ADAPTER = _linkedAdapter;
  }

  /*///////////////////////////////////////////////////////////////
                             MESSAGING
  ///////////////////////////////////////////////////////////////*/

  /**
   * @notice Send tokens to other chain through the linked adapter
   * @param _to The target address on the destination chain
   * @param _amount The amount of tokens to send
   * @param _minGasLimit Minimum gas limit that the message can be executed with
   */
  function sendMessage(address _to, uint256 _amount, uint32 _minGasLimit) external virtual;

  /**
   * @notice Send signer tokens to other chain through the linked adapter
   * @param _signer The address of the user sending the message
   * @param _to The target address on the destination chain
   * @param _amount The amount of tokens to send
   * @param _signature The signature of the user
   * @param _nonce The nonce of the user
   * @param _deadline The deadline for the message to be executed
   * @param _minGasLimit Minimum gas limit that the message can be executed with
   */
  function sendMessage(
    address _signer,
    address _to,
    uint256 _amount,
    bytes calldata _signature,
    uint256 _nonce,
    uint256 _deadline,
    uint32 _minGasLimit
  ) external virtual;

  /**
   * @notice Receive the message from the other chain and mint the bridged representation for the user
   * @dev This function should only be called when receiving a message to mint the bridged representation
   * @param _user The user to mint the bridged representation for
   * @param _spender The address that provided the tokens
   * @param _amount The amount of tokens to mint
   */
  function receiveMessage(address _user, address _spender, uint256 _amount) external virtual;

  /**
   * @notice Withdraws the blacklisted funds from the contract if they get unblacklisted
   * @param _user The user to withdraw the funds for
   */
  function withdrawBlacklistedFunds(address _user) external virtual;

  /**
   * @notice Cancels a signature by setting the nonce as used
   * @param _nonce The nonce of the signature to cancel
   */
  function cancelSignature(uint256 _nonce) external {
    userNonces[msg.sender][_nonce] = true;
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
