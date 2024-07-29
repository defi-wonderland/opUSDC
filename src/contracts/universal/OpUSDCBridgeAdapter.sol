// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import {EIP712Upgradeable} from '@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol';
import {MessageHashUtils} from '@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol';
import {SignatureChecker} from '@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol';
import {IOpUSDCBridgeAdapter} from 'interfaces/IOpUSDCBridgeAdapter.sol';

abstract contract OpUSDCBridgeAdapter is UUPSUpgradeable, OwnableUpgradeable, EIP712Upgradeable, IOpUSDCBridgeAdapter {
  using MessageHashUtils for bytes32;
  using SignatureChecker for address;

  /// @notice The typehash for the bridge message
  bytes32 public constant BRIDGE_MESSAGE_TYPEHASH =
    keccak256('BridgeMessage(address to,uint256 amount,uint256 deadline,uint256 nonce,uint32 minGasLimit)');

  /// @inheritdoc IOpUSDCBridgeAdapter
  address public immutable USDC;

  /// @inheritdoc IOpUSDCBridgeAdapter
  address public immutable LINKED_ADAPTER;

  /// @inheritdoc IOpUSDCBridgeAdapter
  address public immutable MESSENGER;

  /// @notice Reserve 50 storage slots to be safe on future upgrades
  uint256[50] private __gap;

  /// @inheritdoc IOpUSDCBridgeAdapter
  Status public messengerStatus;

  /// @inheritdoc IOpUSDCBridgeAdapter
  mapping(address _user => mapping(uint256 _nonce => bool _used)) public userNonces;

  /// @inheritdoc IOpUSDCBridgeAdapter
  mapping(address _spender => mapping(address _user => uint256 _blacklistedAmount)) public blacklistedFundsDetails;

  /**
   * @notice Construct the OpUSDCBridgeAdapter contract
   * @param _usdc The address of the USDC Contract to be used by the adapter
   * @param _messenger The address of the messenger contract
   * @param _linkedAdapter The address of the linked adapter
   */
  // solhint-disable-next-line no-unused-vars
  constructor(address _usdc, address _messenger, address _linkedAdapter) {
    USDC = _usdc;
    MESSENGER = _messenger;
    LINKED_ADAPTER = _linkedAdapter;
    _disableInitializers();
  }

  /**
   * @notice Initialize the contract
   * @param _owner The owner of the contract
   */
  function initialize(address _owner) external virtual initializer {}

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
   * @param _spender The address that provided the tokens
   * @param _user The user to withdraw the funds for
   */
  function withdrawBlacklistedFunds(address _spender, address _user) external virtual;

  /**
   * @notice Cancels a signature by setting the nonce as used
   * @param _nonce The nonce of the signature to cancel
   */
  function cancelSignature(uint256 _nonce) external {
    userNonces[msg.sender][_nonce] = true;
  }

  /**
   * @notice Checks the caller is the owner to authorize the upgrade
   */
  function _authorizeUpgrade(address) internal virtual override onlyOwner {}

  /**
   * @notice Check the signature of a message
   * @param _signer the address that signed the message
   * @param _messageHash the hash of the message that was signed
   * @param _signature the signature of the message
   */
  function _checkSignature(address _signer, bytes32 _messageHash, bytes memory _signature) internal view {
    // Uses the EIP712Upgradeable typed data hash
    _messageHash = _hashTypedDataV4(_messageHash);

    if (!_signer.isValidSignatureNow(_messageHash, _signature)) revert IOpUSDCBridgeAdapter_InvalidSignature();
  }

  /**
   * @notice Hashes the bridge message struct
   * @param _message The bridge message struct to hash
   * @return _hash The hash of the bridge message struct
   */
  function _hashMessageStruct(BridgeMessage memory _message) internal pure returns (bytes32 _hash) {
    _hash = keccak256(
      abi.encode(
        BRIDGE_MESSAGE_TYPEHASH, _message.to, _message.amount, _message.deadline, _message.nonce, _message.minGasLimit
      )
    );
  }
}
