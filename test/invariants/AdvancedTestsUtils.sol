// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Test} from 'forge-std/Test.sol';
import {MockERC20} from 'forge-std/mocks/MockERC20.sol';
import {SymTest} from 'halmos-cheatcodes/SymTest.sol';

interface IHevm {
  // Set block.timestamp to newTimestamp
  function warp(uint256 newTimestamp) external;

  // Set block.number to newNumber
  function roll(uint256 newNumber) external;

  // Add the condition b to the assumption base for the current branch
  // This function is almost identical to require
  function assume(bool b) external;

  // Sets the eth balance of usr to amt
  function deal(address usr, uint256 amt) external;

  // Loads a storage slot from an address
  function load(address where, bytes32 slot) external returns (bytes32);

  // Stores a value to an address' storage slot
  function store(address where, bytes32 slot, bytes32 value) external;

  // Signs data (privateKey, digest) => (v, r, s)
  function sign(uint256 privateKey, bytes32 digest) external returns (uint8 v, bytes32 r, bytes32 s);

  // Gets address for a given private key
  function addr(uint256 privateKey) external returns (address addr);

  // Performs a foreign function call via terminal
  function ffi(string[] calldata inputs) external returns (bytes memory result);

  // Performs the next smart contract call with specified `msg.sender`
  function prank(address newSender) external;

  // Creates a new fork with the given endpoint and the latest block and returns the identifier of the fork
  function createFork(string calldata urlOrAlias) external returns (uint256);

  // Takes a fork identifier created by createFork and sets the corresponding forked state as active
  function selectFork(uint256 forkId) external;

  // Returns the identifier of the current fork
  function activeFork() external returns (uint256);

  // Labels the address in traces
  function label(address addr, string calldata label) external;
}

contract FuzzERC20 is MockERC20 {
  function mint(address _to, uint256 _amount) public {
    _mint(_to, _amount);
  }

  function burn(address _from, uint256 _amount) public {
    _burn(_from, _amount);
  }
}

contract AgentsHandler {
  uint256 internal _agentsIndex;
  address[] internal _agents;

  address internal _currentCaller;

  modifier agentOrDeployer() {
    uint256 _currentAgentIndex = _agentsIndex;
    _currentCaller = _currentAgentIndex == 0 ? address(this) : _agents[_agentsIndex];
    _;
  }

  constructor(uint256 _numAgents) {
    for (uint256 i = 0; i < _numAgents; i++) {
      _agents.push(address(bytes20(keccak256(abi.encodePacked(i)))));
    }
  }

  function nextAgent() public {
    _agentsIndex = (_agentsIndex + 1) % _agents.length;
  }

  function getCurrentAgent() public view returns (address) {
    return _agents[_agentsIndex];
  }

  function _addToAgents(address _newAgent) internal {
    _agents.push(_newAgent);
  }
}

contract EchidnaTest is AgentsHandler {
  event AssertionFailed();

  IHevm hevm = IHevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

  constructor() AgentsHandler(5) {}

  function clamp(uint256 _value, uint256 _min, uint256 _max) internal pure returns (uint256) {
    return _min + (_value % (_max - _min));
  }

  function max(uint256 a, uint256 b) internal pure returns (uint256) {
    return a > b ? a : b;
  }

  function min(uint256 a, uint256 b) internal pure returns (uint256) {
    return a < b ? a : b;
  }
}

contract HalmosTest is SymTest, Test {}

library HalmosUtils {
  function computeCreateAddress(address _origin, uint256 _nonce) internal pure returns (address _address) {
    bytes memory _data;
    if (_nonce == 0x00) {
      _data = abi.encodePacked(bytes1(0xd6), bytes1(0x94), _origin, bytes1(0x80));
    } else if (_nonce <= 0x7f) {
      _data = abi.encodePacked(bytes1(0xd6), bytes1(0x94), _origin, uint8(_nonce));
    } else if (_nonce <= 0xff) {
      _data = abi.encodePacked(bytes1(0xd7), bytes1(0x94), _origin, bytes1(0x81), uint8(_nonce));
    } else if (_nonce <= 0xffff) {
      _data = abi.encodePacked(bytes1(0xd8), bytes1(0x94), _origin, bytes1(0x82), uint16(_nonce));
    } else if (_nonce <= 0xffffff) {
      _data = abi.encodePacked(bytes1(0xd9), bytes1(0x94), _origin, bytes1(0x83), uint24(_nonce));
    } else {
      _data = abi.encodePacked(bytes1(0xda), bytes1(0x94), _origin, bytes1(0x84), uint32(_nonce));
    }

    bytes32 _hash = keccak256(_data);
    assembly {
      mstore(0, _hash)
      _address := mload(0)
    }
  }
}
