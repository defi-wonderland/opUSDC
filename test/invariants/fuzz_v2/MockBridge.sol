// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {ITestCrossDomainMessenger} from 'test/utils/interfaces/ITestCrossDomainMessenger.sol';

// Relay any message
contract MockBridge is ITestCrossDomainMessenger {
  uint256 public messageNonce;

  address internal _currentXDomSender;

  function OTHER_MESSENGER() external pure returns (address) {
    return address(0);
  }

  function xDomainMessageSender() external view returns (address) {
    return _currentXDomSender;
  }

  function sendMessage(address _target, bytes calldata _message, uint32) external {
    messageNonce++;

    (bool success,) = _target.call(_message);
    success;
  }

  function relayMessage(
    uint256,
    address,
    address _target,
    uint256 _value,
    uint256,
    bytes calldata _message
  ) external payable {
    _currentXDomSender = msg.sender;
    messageNonce++;
    (bool succ, bytes memory ret) = _target.call{value: _value}(_message);

    if (!succ) revert(string(ret));
  }

  function setDomaninMessageSender(address _sender) external {
    _currentXDomSender = _sender;
  }
}
