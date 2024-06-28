// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {ITestCrossDomainMessenger} from 'test/utils/interfaces/ITestCrossDomainMessenger.sol';

// Relay any message
contract MockBridge is ITestCrossDomainMessenger {
  struct QueuedMessage {
    address xdomainSender;
    address target;
    bytes message;
  }

  uint256 public messageNonce;
  address public l1Adapter;

  address internal _currentXDomSender;
  QueuedMessage[] internal _queuedMessages;

  function OTHER_MESSENGER() external pure returns (address) {
    return address(0);
  }

  function xDomainMessageSender() external view returns (address) {
    return _currentXDomSender;
  }

  function isInQueue(address _target, bytes calldata _message, address _xdomainSender) external view returns (bool) {
    for (uint256 i = 0; i < _queuedMessages.length; i++) {
      QueuedMessage memory message = _queuedMessages[i];
      if (
        message.target == _target && keccak256(message.message) == keccak256(_message)
          && message.xdomainSender == _xdomainSender
      ) {
        return true;
      }
    }
    return false;
  }

  function sendMessage(address _target, bytes calldata _message, uint32) external {
    messageNonce++;

    QueuedMessage memory newMessage = QueuedMessage({xdomainSender: msg.sender, target: _target, message: _message});

    _queuedMessages.push(newMessage);
  }

  // assuming FIFO sequencer (todo: check this assumption)
  function executeMessage() external {
    QueuedMessage memory nextMessage = _queuedMessages[0];

    _currentXDomSender = nextMessage.xdomainSender;

    (bool success,) = nextMessage.target.call(nextMessage.message);
    success;

    // Reorg the queue
    for (uint256 i = 1; i < _queuedMessages.length; i++) {
      _queuedMessages[i - 1] = _queuedMessages[i];
    }
    _queuedMessages.pop();
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

    if (!succ) {
      revert(string(ret));
    }
  }
}
