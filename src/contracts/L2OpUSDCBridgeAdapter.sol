// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {OpUSDCBridgeAdapter} from 'contracts/universal/OpUSDCBridgeAdapter.sol';
import {BytecodeDeployer} from 'contracts/utils/BytecodeDeployer.sol';
import {IL2OpUSDCBridgeAdapter} from 'interfaces/IL2OpUSDCBridgeAdapter.sol';
import {ICrossDomainMessenger} from 'interfaces/external/ICrossDomainMessenger.sol';
import {IUSDC} from 'interfaces/external/IUSDC.sol';

contract L2OpUSDCBridgeAdapter is IL2OpUSDCBridgeAdapter, OpUSDCBridgeAdapter {
  /**
   * @notice USDC function signatures
   */
  bytes4 internal constant _TRANSFER_OWNERSHIP_SELECTOR = 0xf2fde38b;
  bytes4 internal constant _CHANGE_ADMIN_SELECTOR = 0x8f283970;

  /// @inheritdoc IL2OpUSDCBridgeAdapter
  bool public isMessagingDisabled;

  /**
   * @notice Modifier to check if the sender is the linked adapter through the messenger
   */
  modifier checkSender() {
    if (msg.sender != MESSENGER || ICrossDomainMessenger(MESSENGER).xDomainMessageSender() != LINKED_ADAPTER) {
      revert IOpUSDCBridgeAdapter_InvalidSender();
    }
    _;
  }

  /**
   * @notice Construct the OpUSDCBridgeAdapter contract
   * @param _usdc The address of the USDC Contract to be used by the adapter
   * @param _messenger The address of the messenger contract
   * @param _linkedAdapter The address of the linked adapter
   * @dev The constructor is only used to initialize the OpUSDCBridgeAdapter immutable variables
   */
  /* solhint-disable no-unused-vars */
  constructor(
    address _usdc,
    address _messenger,
    address _linkedAdapter,
    address _owner
  ) OpUSDCBridgeAdapter(_usdc, _messenger, _linkedAdapter, _owner) {}
  /* solhint-enable no-unused-vars */

  /*///////////////////////////////////////////////////////////////
                              MIGRATION
  ///////////////////////////////////////////////////////////////*/

  /**
   * @notice Initiates the process to migrate the bridged USDC to native USDC
   * @dev Full migration cant finish until L1 receives the message for setting the burn amount
   * @param _newOwner The address to transfer ownerships to
   * @param _setBurnAmountMinGasLimit Minimum gas limit that the setBurnAmount message can be executed on L1
   */
  function receiveMigrateToNative(address _newOwner, uint32 _setBurnAmountMinGasLimit) external checkSender {
    isMessagingDisabled = true;
    // Transfer ownership of the USDC contract to circle
    IUSDC(USDC).transferOwnership(_newOwner);

    //Transfer proxy admin ownership to circle
    IUSDC(USDC).changeAdmin(_newOwner);

    uint256 _burnAmount = IUSDC(USDC).totalSupply();

    ICrossDomainMessenger(MESSENGER).sendMessage(
      LINKED_ADAPTER, abi.encodeWithSignature('setBurnAmount(uint256)', _burnAmount), _setBurnAmountMinGasLimit
    );

    emit MigratingToNative(MESSENGER, _newOwner);
  }

  /*///////////////////////////////////////////////////////////////
                          MESSAGING CONTROL
  ///////////////////////////////////////////////////////////////*/

  /**
   * @notice Receive the stop messaging message from the linked adapter and stop outgoing messages
   */
  function receiveStopMessaging() external checkSender {
    isMessagingDisabled = true;

    emit MessagingStopped(MESSENGER);
  }

  /**
   * @notice Resume messaging after it was stopped
   */
  function receiveResumeMessaging() external checkSender {
    // NOTE: This is safe because this message can only be received when messaging is not deprecated on the L1 messenger
    isMessagingDisabled = false;

    emit MessagingResumed(MESSENGER);
  }

  /*///////////////////////////////////////////////////////////////
                             MESSAGING
  ///////////////////////////////////////////////////////////////*/

  /**
   * @notice Send tokens to other chain through the linked adapter
   * @param _to The target address on the destination chain
   * @param _amount The amount of tokens to send
   * @param _minGasLimit Minimum gas limit that the message can be executed with
   */
  function sendMessage(address _to, uint256 _amount, uint32 _minGasLimit) external override {
    // Ensure messaging is enabled
    if (isMessagingDisabled) revert IOpUSDCBridgeAdapter_MessagingDisabled();

    // Burn the tokens
    IUSDC(USDC).burn(msg.sender, _amount);

    // Send the message to the linked adapter
    ICrossDomainMessenger(MESSENGER).sendMessage(
      LINKED_ADAPTER, abi.encodeWithSignature('receiveMessage(address,uint256)', _to, _amount), _minGasLimit
    );

    emit MessageSent(msg.sender, _to, _amount, MESSENGER, _minGasLimit);
  }

  /**
   * @notice Send tokens to other chain through the linked adapter
   * @param _signer The address of the user sending the message
   * @param _to The target address on the destination chain
   * @param _amount The amount of tokens to send
   * @param _signature The signature of the user
   * @param _deadline The deadline for the message to be executed
   * @param _minGasLimit Minimum gas limit that the message can be executed with
   */
  function sendMessage(
    address _signer,
    address _to,
    uint256 _amount,
    bytes calldata _signature,
    uint256 _deadline,
    uint32 _minGasLimit
  ) external override {
    // Ensure messaging is enabled
    if (isMessagingDisabled) revert IOpUSDCBridgeAdapter_MessagingDisabled();

    // Ensure the deadline has not passed
    if (block.timestamp > _deadline) revert IOpUSDCBridgeAdapter_MessageExpired();

    // Hash the message
    bytes32 _messageHash = keccak256(abi.encode(address(this), block.chainid, _to, _amount, userNonce[_signer]++));

    _checkSignature(_signer, _messageHash, _signature);

    // Burn the tokens
    IUSDC(USDC).burn(_signer, _amount);

    // Send the message to the linked adapter
    ICrossDomainMessenger(MESSENGER).sendMessage(
      LINKED_ADAPTER, abi.encodeWithSignature('receiveMessage(address,uint256)', _to, _amount), _minGasLimit
    );

    emit MessageSent(_signer, _to, _amount, MESSENGER, _minGasLimit);
  }

  /**
   * @notice Receive the message from the other chain and mint the bridged representation for the user
   * @dev This function should only be called when receiving a message to mint the bridged representation
   * @param _user The user to mint the bridged representation for
   * @param _amount The amount of tokens to mint
   */
  function receiveMessage(address _user, uint256 _amount) external override checkSender {
    // Mint the tokens to the user
    IUSDC(USDC).mint(_user, _amount);
    emit MessageReceived(_user, _amount, MESSENGER);
  }

  /*///////////////////////////////////////////////////////////////
                        BRIDGED USDC FUNCTIONS
  ///////////////////////////////////////////////////////////////*/

  /**
   * @notice Send the message from the owner to execute a call with abitrary calldata on USDC contract.
   * @dev can't execute the following list of transactions:
   *  • transferOwnership (0xf2fde38b)
   *  • changeAdmin (0x8f283970)
   */
  function sendUsdcOwnableFunction(bytes calldata _data) external onlyOwner {
    if (_data.length < 4) revert IL2OpUSDCBridgeAdapter_InvalidCalldata();

    //Check forbidden transactions
    bytes4 _signature = bytes4(_data);
    if (_signature == _TRANSFER_OWNERSHIP_SELECTOR || _signature == _CHANGE_ADMIN_SELECTOR) {
      revert IL2OpUSDCBridgeAdapter_ForbiddenTransaction();
    }

    (bool _success,) = USDC.call(_data);
    if (!_success) {
      revert IL2OpUSDCBridgeAdapter_InvalidTransaction();
    }

    emit UsdcOwnableFunctionSent(_signature);
  }
}
