// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IOptimismPortal {
  /// @notice Accepts deposits of ETH and data, and emits a TransactionDeposited event for use in
  ///         deriving deposit transactions. Note that if a deposit is made by a contract, its
  ///         address will be aliased when retrieved using `tx.origin` or `msg.sender`. Consider
  ///         using the CrossDomainMessenger contracts for a simpler developer experience.
  /// @param _to         Target address on L2.
  /// @param _value      ETH value to send to the recipient.
  /// @param _gasLimit   Amount of L2 gas to purchase by burning gas on L1.
  /// @param _isCreation Whether or not the transaction is a contract creation.
  /// @param _data       Data to trigger the recipient with.
  function depositTransaction(
    address _to,
    uint256 _value,
    uint64 _gasLimit,
    bool _isCreation,
    bytes memory _data
  ) external payable;
}
