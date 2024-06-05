// SPDX-License-Identifier: Apache-2.0

/*
 * Copyright 2019-2021, Offchain Labs, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

pragma solidity 0.8.25;

library AddressAliasHelper {
  uint160 internal constant _OFFSET = uint160(0x1111000000000000000000000000000000001111);

  /// @notice Utility function that converts the address in the L1 that submitted a tx to
  /// the inbox to the msg.sender viewed in the L2
  /// @param _l1Address the address in the L1 that triggered the tx to L2
  /// @return _l2Address L2 address as viewed in msg.sender
  function applyL1ToL2Alias(address _l1Address) internal pure returns (address _l2Address) {
    unchecked {
      _l2Address = address(uint160(_l1Address) + _OFFSET);
    }
  }

  /// @notice Utility function that converts the msg.sender viewed in the L2 to the
  /// address in the L1 that submitted a tx to the inbox
  /// @param _l2Address L2 address as viewed in msg.sender
  /// @return _l1Address the address in the L1 that triggered the tx to L2
  function undoL1ToL2Alias(address _l2Address) internal pure returns (address _l1Address) {
    unchecked {
      _l1Address = address(uint160(_l2Address) - _OFFSET);
    }
  }
}
