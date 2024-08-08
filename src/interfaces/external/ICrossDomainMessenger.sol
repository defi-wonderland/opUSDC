pragma solidity 0.8.25;

interface ICrossDomainMessenger {
  /**
   * @notice Sends a message to some target address on the other chain. Note that if the call
   *         always reverts, then the message will be unrelayable, and any ETH sent will be
   *         permanently locked. The same will occur if the target on the other chain is
   *         considered unsafe (see the _isUnsafeTarget() function).
   * @param _target      Target contract or wallet address.
   * @param _message     Message to trigger the target address with.
   * @param _minGasLimit Minimum gas limit that the message can be executed with.
   */
  function sendMessage(address _target, bytes calldata _message, uint32 _minGasLimit) external;

  /**
   * @notice Retrieves the address of the contract or wallet that initiated the currently
   *         executing message on the other chain. Will throw an error if there is no message
   *         currently being executed. Allows the recipient of a call to see who triggered it.
   * @return _sender Address of the sender of the currently executing message on the other chain.
   */
  function xDomainMessageSender() external view returns (address _sender);

  /**
   * @notice Returns the address of the portal.
   * @return _portal Address of the portal.
   */
  function portal() external view returns (address _portal);

  /**
   * @notice Returns the address of the portal.
   * @dev This is a legacy function that is used for any legacy messengers.
   * @return _portal Address of the portal.
   */
  // solhint-disable-next-line func-name-mixedcase
  function PORTAL() external view returns (address _portal);
}
