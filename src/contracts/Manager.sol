// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {IManager} from 'interfaces/IManager.sol';

contract Manager is Ownable, IManager {
  /// @inheritdoc IManager
  address public immutable CIRCLE;

  /// @inheritdoc IManager
  Ownable public immutable CONTROLLED_CONTRACT;

  /**
   * @param _circle The address of the circle contract
   * @param _controlledContract The address of the contract this manages
   */
  constructor(address _circle, Ownable _controlledContract) Ownable(msg.sender) {
    CIRCLE = _circle;
    CONTROLLED_CONTRACT = _controlledContract;
  }

  /**
   * @notice Transfer ownership of the contract this manages to circle
   */
  function transferToCircle() external onlyOwner {
    CONTROLLED_CONTRACT.transferOwnership(CIRCLE);
  }
}
