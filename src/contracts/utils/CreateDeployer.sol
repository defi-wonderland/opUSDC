// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

abstract contract CreateDeployer {
  // /**
  //  * @dev Event that is emitted when a contract is successfully created.
  //  * @param newContract The address of the new contract.
  //  * @param salt The 32-byte random value used to create the contract address.
  //  */
  // event ContractCreation(address indexed newContract, bytes32 indexed salt);

  // /**
  //  * @dev Error that occurs when the contract creation failed.
  //  * @param emitter The contract that emits the error.
  //  */
  // error FailedContractCreation(address emitter);

  // TODO: update
  bytes32 internal constant SALT = bytes32('1');

  /**
   * @dev Returns the address where a contract will be stored if deployed via `deployer` using
   * the `CREATE` opcode. For the specification of the Recursive Length Prefix (RLP) encoding
   * scheme, please refer to p. 19 of the Ethereum Yellow Paper (https://web.archive.org/web/20230921110603/https://ethereum.github.io/yellowpaper/paper.pdf)
   * and the Ethereum Wiki (https://web.archive.org/web/20230921112807/https://ethereum.org/en/developers/docs/data-structures-and-encoding/rlp/).
   * For further insights also, see the following issue: https://web.archive.org/web/20230921112943/https://github.com/transmissions11/solmate/issues/207.
   *
   * Based on the EIP-161 (https://web.archive.org/web/20230921113207/https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-161.md) specification,
   * all contract accounts on the Ethereum mainnet are initiated with `nonce = 1`. Thus, the
   * first contract address created by another contract is calculated with a non-zero nonce.
   * @param deployer The 20-byte deployer address.
   * @param nonce The next 32-byte nonce of the deployer address.
   * @return computedAddress The 20-byte address where a contract will be stored.
   */
  function computeCreateAddress(address deployer, uint256 nonce) public pure returns (address computedAddress) {
    bytes memory data;
    bytes1 len = bytes1(0x94);

    // The theoretical allowed limit, based on EIP-2681, for an account nonce is 2**64-2:
    // https://web.archive.org/web/20230921113252/https://eips.ethereum.org/EIPS/eip-2681.
    if (nonce > type(uint64).max - 1) {
      revert('TODO');
    }

    // The integer zero is treated as an empty byte string and therefore has only one length prefix,
    // 0x80, which is calculated via 0x80 + 0.
    if (nonce == 0x00) {
      data = abi.encodePacked(bytes1(0xd6), len, deployer, bytes1(0x80));
    }
    // A one-byte integer in the [0x00, 0x7f] range uses its own value as a length prefix, there is no
    // additional "0x80 + length" prefix that precedes it.
    else if (nonce <= 0x7f) {
      data = abi.encodePacked(bytes1(0xd6), len, deployer, uint8(nonce));
    }
    // In the case of `nonce > 0x7f` and `nonce <= type(uint8).max`, we have the following encoding scheme
    // (the same calculation can be carried over for higher nonce bytes):
    // 0xda = 0xc0 (short RLP prefix) + 0x1a (= the bytes length of: 0x94 + address + 0x84 + nonce, in hex),
    // 0x94 = 0x80 + 0x14 (= the bytes length of an address, 20 bytes, in hex),
    // 0x84 = 0x80 + 0x04 (= the bytes length of the nonce, 4 bytes, in hex).
    else if (nonce <= type(uint8).max) {
      data = abi.encodePacked(bytes1(0xd7), len, deployer, bytes1(0x81), uint8(nonce));
    } else if (nonce <= type(uint16).max) {
      data = abi.encodePacked(bytes1(0xd8), len, deployer, bytes1(0x82), uint16(nonce));
    } else if (nonce <= type(uint24).max) {
      data = abi.encodePacked(bytes1(0xd9), len, deployer, bytes1(0x83), uint24(nonce));
    } else if (nonce <= type(uint32).max) {
      data = abi.encodePacked(bytes1(0xda), len, deployer, bytes1(0x84), uint32(nonce));
    } else if (nonce <= type(uint40).max) {
      data = abi.encodePacked(bytes1(0xdb), len, deployer, bytes1(0x85), uint40(nonce));
    } else if (nonce <= type(uint48).max) {
      data = abi.encodePacked(bytes1(0xdc), len, deployer, bytes1(0x86), uint48(nonce));
    } else if (nonce <= type(uint56).max) {
      data = abi.encodePacked(bytes1(0xdd), len, deployer, bytes1(0x87), uint56(nonce));
    } else {
      data = abi.encodePacked(bytes1(0xde), len, deployer, bytes1(0x88), uint64(nonce));
    }

    computedAddress = address(uint160(uint256(keccak256(data))));
  }

  /**
   * @dev Deploys a new contract via employing the `CREATE3` pattern (i.e. without an initcode
   * factor) and using the salt value `salt`, the creation bytecode `initCode`, and `msg.value`
   * as inputs. In order to save deployment costs, we do not sanity check the `initCode` length.
   * Note that if `msg.value` is non-zero, `initCode` must have a `payable` constructor. This
   * implementation is based on Solmate:
   * https://web.archive.org/web/20230921113832/https://raw.githubusercontent.com/transmissions11/solmate/e8f96f25d48fe702117ce76c79228ca4f20206cb/src/utils/CREATE3.sol.
   * @param salt The 32-byte random value used to create the proxy contract address.
   * @param initCode The creation bytecode.
   * @return newContract The 20-byte address where the contract was deployed.
   * @custom:security We strongly recommend implementing a permissioned deploy protection by setting
   * the first 20 bytes equal to `msg.sender` in the `salt` to prevent maliciously intended frontrun
   * proxy deployments on other chains.
   */
  function deployCreate3(bytes32 salt, bytes memory initCode) internal returns (address newContract) {
    bytes memory proxyChildBytecode = hex'67363d3d37363d34f03d5260086018f3';
    address proxy;
    assembly ("memory-safe") {
      proxy := create2(0, add(proxyChildBytecode, 32), mload(proxyChildBytecode), salt)
    }
    if (proxy == address(0)) {
      revert('TODO');
    }
    // emit Create3ProxyContractCreation({newContract: proxy, salt: salt});

    newContract = computeCreate3Address(salt, address(this));
    (bool success,) = proxy.call{value: msg.value}(initCode);
    if (!success || newContract == address(0) || newContract.code.length == 0) {
      revert('TODO'); // FailedContractCreation({emitter: _SELF});
    }
    // emit ContractCreation({newContract: newContract});
  }

  /**
   * @dev Returns the address where a contract will be stored if deployed via `deployer` using
   * the `CREATE3` pattern (i.e. without an initcode factor). Any change in the `salt` value will
   * result in a new destination address. This implementation is based on Solady:
   * https://web.archive.org/web/20230921114120/https://raw.githubusercontent.com/Vectorized/solady/1c1ac4ad9c8558001e92d8d1a7722ef67bec75df/src/utils/CREATE3.sol.
   * @param salt The 32-byte random value used to create the proxy contract address.
   * @param deployer The 20-byte deployer address.
   * @return computedAddress The 20-byte address where a contract will be stored.
   */
  function computeCreate3Address(bytes32 salt, address deployer) internal pure returns (address computedAddress) {
    assembly ("memory-safe") {
      let ptr := mload(0x40)
      mstore(0x00, deployer)
      mstore8(0x0b, 0xff)
      mstore(0x20, salt)
      mstore(0x40, hex'21c35dbe1b344a2488cf3321d6ce542f8e9f305544ff09e4993a62319a497c1f')
      mstore(0x14, keccak256(0x0b, 0x55))
      mstore(0x40, ptr)
      mstore(0x00, 0xd694)
      mstore8(0x34, 0x01)
      computedAddress := keccak256(0x1e, 0x17)
    }
  }

  /**
   * @dev Returns the address where a contract will be stored if deployed via `deployer` using
   * the `CREATE2` opcode. Any change in the `initCodeHash` or `salt` values will result in a new
   * destination address. This implementation is based on OpenZeppelin:
   * https://web.archive.org/web/20230921113703/https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/181d518609a9f006fcb97af63e6952e603cf100e/contracts/utils/Create2.sol.
   * @param salt The 32-byte random value used to create the contract address.
   * @param initCodeHash The 32-byte bytecode digest of the contract creation bytecode.
   * @param deployer The 20-byte deployer address.
   * @return computedAddress The 20-byte address where a contract will be stored.
   */
  function computeCreate2Address(
    bytes32 salt,
    bytes32 initCodeHash,
    address deployer
  ) internal pure returns (address computedAddress) {
    assembly ("memory-safe") {
      // |                      | ↓ ptr ...  ↓ ptr + 0x0B (start) ...  ↓ ptr + 0x20 ...  ↓ ptr + 0x40 ...   |
      // |----------------------|---------------------------------------------------------------------------|
      // | initCodeHash         |                                                        CCCCCCCCCCCCC...CC |
      // | salt                 |                                      BBBBBBBBBBBBB...BB                   |
      // | deployer             | 000000...0000AAAAAAAAAAAAAAAAAAA...AA                                     |
      // | 0xFF                 |            FF                                                             |
      // |----------------------|---------------------------------------------------------------------------|
      // | memory               | 000000...00FFAAAAAAAAAAAAAAAAAAA...AABBBBBBBBBBBBB...BBCCCCCCCCCCCCC...CC |
      // | keccak256(start, 85) |            ↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑ |
      let ptr := mload(0x40)
      mstore(add(ptr, 0x40), initCodeHash)
      mstore(add(ptr, 0x20), salt)
      mstore(ptr, deployer)
      let start := add(ptr, 0x0b)
      mstore8(start, 0xff)
      computedAddress := keccak256(start, 85)
    }
  }

  /**
   * @dev Deploys a new contract via calling the `CREATE2` opcode and using the salt value `salt`,
   * the creation bytecode `initCode`, and `msg.value` as inputs. In order to save deployment costs,
   * we do not sanity check the `initCode` length. Note that if `msg.value` is non-zero, `initCode`
   * must have a `payable` constructor.
   * @param salt The 32-byte random value used to create the contract address.
   * @param initCode The creation bytecode.
   * @return newContract The 20-byte address where the contract was deployed.
   */
  function deployCreate2(bytes32 salt, bytes memory initCode) internal returns (address newContract) {
    assembly ("memory-safe") {
      newContract := create2(callvalue(), add(initCode, 0x20), mload(initCode), salt)
    }
    _requireSuccessfulContractCreation({newContract: newContract});
    // emit ContractCreation({newContract: newContract, salt: salt});
  }

  /**
   * @dev Ensures that `newContract` is a non-zero byte contract.
   * @param newContract The 20-byte address where the contract was deployed.
   */
  function _requireSuccessfulContractCreation(address newContract) internal view {
    if (newContract == address(0) || newContract.code.length == 0) {
      // revert FailedContractCreation({emitter: address(this)});
    }
  }
}
