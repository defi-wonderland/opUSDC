// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface IOpUSDCBridgeAdapter {
  /*///////////////////////////////////////////////////////////////
                            EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when the linked adapter is set
   * @param _linkedAdapter Address of the linked adapter
   */
  event LinkedAdapterSet(address _linkedAdapter);

  /*///////////////////////////////////////////////////////////////
                            ERRORS
  //////////////////////////////////////////////////////////////*/

  /*///////////////////////////////////////////////////////////////
                            VARIABLES
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Address of the Bridged USDC token
   */
  function BRIDGED_USDC() external view returns (address);

  /**
   * @notice Address of the OpUSDC Lockbox
   * @dev Should be address(0) on L2's
   */
  function LOCKBOX() external view returns (address);

  /**
   * @notice Address of the CrossDomainMessenger to send messages to L1 <-> L2
   */
  function MESSENGER() external view returns (address);

  /**
   * @notice Address of the linked adapter on L2 to send messages to and receive from
   */
  function linkedAdapter() external view returns (address);

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  //////////////////////////////////////////////////////////////*/
}
