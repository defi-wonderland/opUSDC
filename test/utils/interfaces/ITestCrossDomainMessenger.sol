pragma solidity 0.8.25;

import {ICrossDomainMessenger} from 'interfaces/external/ICrossDomainMessenger.sol';

/**
 * @notice CrossDomainMessenger interface with defined methods only used for testing.
 */
interface ITestCrossDomainMessenger is ICrossDomainMessenger {
  /**
   * @notice Relays a message that was sent by the other CrossDomainMessenger contract. Can only be executed via
   * cross-chain call from the other messenger OR if the message was already received once and is currently being
   * replayed.
   * @param _nonce Nonce of the message being relayed.
   * @param _sender Address of the user who sent the message.
   * @param _target Address that the message is targeted at.
   * @param _value ETH value to send with the message.
   * @param _minGasLimit Minimum amount of gas that the message can be executed with.
   * @param _message Message to send to the target.
   */
  function relayMessage(
    uint256 _nonce,
    address _sender,
    address _target,
    uint256 _value,
    uint256 _minGasLimit,
    bytes calldata _message
  ) external payable;

  /**
   * @return _messageNonce The nonce of the last message sent by the other messenger.
   */
  function messageNonce() external view returns (uint256 _messageNonce);

  /**
   * @return _otherMessenger The address of the messenger contract on the other network
   */
  function OTHER_MESSENGER() external view returns (address _otherMessenger);
}
