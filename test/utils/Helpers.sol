// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from 'forge-std/Test.sol';

contract Helpers is Test {
  /**
   * @notice Sets up a mock and expects a call to it
   *
   * @param _receiver The address to have a mock on
   * @param _calldata The calldata to mock and expect
   * @param _returned The data to return from the mocked call
   */
  function _mockAndExpect(address _receiver, bytes memory _calldata, bytes memory _returned) internal {
    vm.mockCall(_receiver, _calldata, _returned);
    vm.expectCall(_receiver, _calldata);
  }
}
