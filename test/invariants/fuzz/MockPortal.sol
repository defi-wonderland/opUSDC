// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {IOptimismPortal} from 'interfaces/external/IOptimismPortal.sol';

contract MockPortal is IOptimismPortal {
  function depositTransaction(
    address _to,
    uint256 _value,
    uint64 _gasLimit,
    bool _isCreation,
    bytes memory _data
  ) external payable override {
    // do nothing
  }
}
