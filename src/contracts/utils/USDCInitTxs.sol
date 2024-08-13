// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IUSDC} from 'interfaces/external/IUSDC.sol';

/**
 * @notice Library containing the initialization transactions constants (without the first one) for the USDC
 *  implementation contract defined by Circle.
 */
library USDCInitTxs {
  /**
   * @dev The `initializeV2()` transaction data for the USDC implementation contract.
   */
  bytes public constant INITIALIZEV2 = abi.encodeCall(IUSDC.initializeV2, ('Bridged USDC'));

  /**
   * @dev The `initializeV2_1()` transaction data for the USDC implementation contract.
   */
  bytes public constant INITIALIZEV2_1 = abi.encodeCall(IUSDC.initializeV2_1, (address(0)));

  /**
   * @dev The `initializeV2_2()` transaction data for the USDC implementation contract.
   */
  bytes public constant INITIALIZEV2_2 = abi.encodeCall(IUSDC.initializeV2_2, (new address[](0), 'USDC.e'));
}
