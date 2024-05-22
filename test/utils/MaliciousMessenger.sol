// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

contract MaliciousMessenger {
  address public fakeMessenger;

  constructor(address _fakeMessenger) {
    fakeMessenger = _fakeMessenger;
  }

  function xDomainMessageSender() external view returns (address) {
    return fakeMessenger;
  }
}
