pragma solidity 0.8.25;

import {ShortString, ShortStrings} from '@openzeppelin/contracts/utils/ShortStrings.sol';
import {IOpUSDCBridgeAdapter} from 'interfaces/IOpUSDCBridgeAdapter.sol';

contract SigUtils {
  using ShortStrings for *;

  bytes32 private constant _TYPE_HASH =
    keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)');
  bytes32 public constant BRIDGE_MESSAGE_TYPEHASH =
    keccak256('BridgeMessage(address to,uint256 amount,uint256 deadline,uint256 nonce,uint32 minGasLimit)');

  bytes32 internal immutable _DOMAIN_SEPARATOR;

  bytes32 private immutable _HASHED_NAME;
  bytes32 private immutable _HASHED_VERSION;

  ShortString private immutable _NAME;
  ShortString private immutable _VERSION;
  string private _nameFallback;
  string private _versionFallback;

  constructor(address _adapter) {
    string memory _name = 'OpUSDCBridgeAdapter';
    string memory _version = '1.0.0';
    _NAME = _name.toShortStringWithFallback(_nameFallback);
    _VERSION = _version.toShortStringWithFallback(_versionFallback);

    _HASHED_NAME = keccak256(bytes(_name));
    _HASHED_VERSION = keccak256(bytes(_version));

    _DOMAIN_SEPARATOR = keccak256(abi.encode(_TYPE_HASH, _HASHED_NAME, _HASHED_VERSION, block.chainid, _adapter));
  }

  /**
   * @notice Hashes the bridge message struct
   * @param _message The bridge message struct to hash
   * @return _hash The hash of the bridge message struct
   */
  function getBridgeMessageHash(IOpUSDCBridgeAdapter.BridgeMessage memory _message) public view returns (bytes32 _hash) {
    _hash = keccak256(
      abi.encode(
        BRIDGE_MESSAGE_TYPEHASH, _message.to, _message.amount, _message.deadline, _message.nonce, _message.minGasLimit
      )
    );
  }

  /**
   * @notice Hashes the bridge message struct and returns the EIP712 hash
   * @param _message The bridge message struct to hash
   * @return _hash The hash of the bridge message struct
   */
  function getTypedBridgeMessageHash(IOpUSDCBridgeAdapter.BridgeMessage memory _message)
    public
    view
    returns (bytes32 _hash)
  {
    _hash = keccak256(abi.encodePacked('\x19\x01', _DOMAIN_SEPARATOR, getBridgeMessageHash(_message)));
  }
}
