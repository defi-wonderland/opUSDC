// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IManager} from 'interfaces/IManager.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';

contract Manager is Ownable, IManager {
  /// @inheritdoc IManager
  address public immutable CIRCLE;

  /// @inheritdoc IManager
  address public immutable CONTROLLED_CONTRACT;

  /**
   * @param _circle The address of the circle contract
   * @param _controlledContract The address of the contract this manages
   */
  constructor(address _circle, address _controlledContract) Ownable(msg.sender) {
    CIRCLE = _circle;
    CONTROLLED_CONTRACT = _controlledContract;
  }

  /**
   * @notice Transfer ownership of the contract this manages to circle
   */
  function transferOwnership() external onlyOwner {
    Ownable(CONTROLLED_CONTRACT).transferOwnership(CIRCLE);
  }
}
