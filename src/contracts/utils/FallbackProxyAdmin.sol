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
   * @param newAdmin Address to transfer proxy administration to
   * @dev Owner should always be the L2 Adapter
   * @dev This contract needs to be the admin of USDC because of the USDC proxy not allowing admin to interact with implementation
   */
  function changeAdmin(address newAdmin) external onlyOwner {
    IUSDC(USDC).changeAdmin(newAdmin);
  }
}
