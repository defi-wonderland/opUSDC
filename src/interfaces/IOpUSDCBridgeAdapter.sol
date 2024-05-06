// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

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

  /**
   * @notice Error when the caller is not the token issuer
   */
  error IOpUSDCBridgeAdapter_NotTokenIssuer();

  /*///////////////////////////////////////////////////////////////
                            VARIABLES
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Fetches address of the Bridged USDC token
   * @return _bridgedUSDC Address of the bridged USDC token
   */
  function BRIDGED_USDC() external view returns (address _bridgedUSDC);

  /**
   * @notice Fetches address of the OpUSDC Lockbox
   * @dev Should be address(0) on L2's
   * @return _lockbox Address of the lockbox
   */
  function LOCKBOX() external view returns (address _lockbox);

  /**
   * @notice Fetches address of the CrossDomainMessenger to send messages to L1 <-> L2
   * @return _messenger Address of the messenger
   */
  function MESSENGER() external view returns (address _messenger);

  /**
   * @notice Fetches address of the linked adapter on L2 to send messages to and receive from
   * @return _linkedAdapter Address of the linked adapter
   */
  function linkedAdapter() external view returns (address _linkedAdapter);

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  //////////////////////////////////////////////////////////////*/
}
