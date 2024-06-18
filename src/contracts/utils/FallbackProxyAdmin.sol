// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {IUSDC} from 'interfaces/external/IUSDC.sol';

contract FallbackProxyAdmin is Ownable {
  /// @notice USDC address
  address public immutable USDC;

  /**
   * @notice Construct the FallbackProxyAdmin contract
   */
  constructor(address _usdc) Ownable(msg.sender) {
    USDC = _usdc;
  }

  /**
   * @notice Changes the admin of the USDC proxy
   * @param _newAdmin Address to transfer proxy administration to
   * @dev Owner should always be the L2 Adapter
   * @dev USDC admin cant interact proxy with implementation so we use this contract as the middleman
   */
  function changeAdmin(address _newAdmin) external onlyOwner {
    IUSDC(USDC).changeAdmin(_newAdmin);
  }

  /**
   * @notice Function to upgrade the usdc proxy to a new implementation
   * @param _newImplementation Address of the new implementation
   */
  function upgradeTo(address _newImplementation) external onlyOwner {
    IUSDC(USDC).upgradeTo(_newImplementation);
  }

  /**
   * @notice Upgrades the USDC proxy to a new implementation and calls a function on the new implementation
   * @param _newImplementation Address of the new implementation
   * @param _data Data to call on the new implementation
   */
  function upgradeToAndCall(address _newImplementation, bytes calldata _data) external onlyOwner {
    IUSDC(USDC).upgradeToAndCall(_newImplementation, _data);
  }
}
