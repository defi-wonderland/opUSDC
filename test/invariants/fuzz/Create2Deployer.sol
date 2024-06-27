// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Identical to the OZ implementation used
contract Create2Deployer {
  // solhint-disable custom-errors
  function deploy(uint256 _value, bytes32 _salt, bytes memory _initCode) public returns (address) {
    address addr;
    require(address(this).balance >= _value, 'Create2: insufficient balance');
    require(_initCode.length != 0, 'Create2: bytecode length is zero');

    assembly {
      addr := create2(_value, add(_initCode, 0x20), mload(_initCode), _salt)
    }
    require(addr != address(0), 'Create2: Failed on deploy');

    return addr;
  }
}
