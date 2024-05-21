// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IL2OpUSDCBridgeAdapter {
  /*///////////////////////////////////////////////////////////////
                            LOGIC
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice Receive the stop messaging message from the linked adapter and stop outgoing messages
   */
  function receiveStopMessaging() external;

  /**
   * @notice Send the message to the linked adapter to mint the bridged representation on the linked chain
   * @param _to The target address on the destination chain
   * @param _amount The amount of tokens to send
   * @param _minGasLimit Minimum gas limit that the message can be executed with
   */
  function sendMessage(address _to, uint256 _amount, uint32 _minGasLimit) external;

  /*///////////////////////////////////////////////////////////////
                            VARIABLES
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice Fetches address of the CrossDomainMessenger to send messages to L1 <-> L2
   * @return _messenger Address of the messenger
   */
  // solhint-disable-next-line func-name-mixedcase
  function MESSENGER() external view returns (address _messenger);
}
