// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/**
 * @notice Library containing the initialization transactions constants for the USDC implementation contract defined
 * by Circle.
 */
library USDCInitTxs {
  /**
   * @dev The `initialize()` transaction data for the USDC implementation contract.
   */
  bytes public constant INITIALIZE = abi.encodeWithSignature(
    'initialize(string,string,string,uint8,address,address,address,address)',
    '',
    '',
    '',
    0,
    address(1),
    address(1),
    address(1),
    address(1)
  );

  /**
   * @dev The `initializeV2()` transaction data for the USDC implementation contract.
   */
  bytes public constant INITIALIZEV2 = abi.encodeWithSignature('initializeV2(string)', '');

  /**
   * @dev The `initializeV2_1()` transaction data for the USDC implementation contract.
   */
  bytes public constant INITIALIZEV2_1 = abi.encodeWithSignature('initializeV2_1(address)', address(1));

  /**
   * @dev The `initializeV2_2()` transaction data for the USDC implementation contract.
   */
  bytes public constant INITIALIZEV2_2 =
    abi.encodeWithSignature('initializeV2_2(address[],string)', new address[](0), 'USDC');
}
