// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {OpUSDCBridgeAdapter} from 'contracts/universal/OpUSDCBridgeAdapter.sol';
import {FallbackProxyAdmin} from 'contracts/utils/FallbackProxyAdmin.sol';
import {IL2OpUSDCBridgeAdapter} from 'interfaces/IL2OpUSDCBridgeAdapter.sol';
import {ICrossDomainMessenger} from 'interfaces/external/ICrossDomainMessenger.sol';
import {IUSDC} from 'interfaces/external/IUSDC.sol';

/**
 * @title L2OpUSDCBridgeAdapter
 * @notice L2OpUSDCBridgeAdapter is a contract that bridges Bridged USDC from L2 to L1 and and receives the it from L1.
 * It finalizes the migration process of bridged USDC to native USDC on L2 after being triggered by the L1 adapter, and
 * sends the amount to be burned back to the L1 adapter to finish the migration process.
 * @dev The owner of this contract is capable of calling any USDC function, except the ownership or admin ones.
 */
contract L2OpUSDCBridgeAdapter is IL2OpUSDCBridgeAdapter, OpUSDCBridgeAdapter {
  using SafeERC20 for IUSDC;

  ///@notice `transferOwnership(address)` USDC function selector
  bytes4 internal constant _TRANSFER_OWNERSHIP_SELECTOR = 0xf2fde38b;
  ///@notice `changeAdmin(address)` USDC function selector
  bytes4 internal constant _CHANGE_ADMIN_SELECTOR = 0x8f283970;
  ///@notice `upgradeTo(address)` USDC function selector
  bytes4 internal constant _UPGRADE_TO_SELECTOR = 0x3659cfe6;
  ///@notice `upgradeToAndCall(address,bytes)` USDC function selector
  bytes4 internal constant _UPGRADE_TO_AND_CALL_SELECTOR = 0x4f1ef286;

  /// @inheritdoc IL2OpUSDCBridgeAdapter
  FallbackProxyAdmin public immutable FALLBACK_PROXY_ADMIN;

  /// @inheritdoc IL2OpUSDCBridgeAdapter
  bool public isMessagingDisabled;

  /// @inheritdoc IL2OpUSDCBridgeAdapter
  address public roleCaller;

  /**
   * @notice Modifier to check if the sender is the linked adapter through the messenger
   */
  modifier onlyLinkedAdapter() {
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
  ) OpUSDCBridgeAdapter(_usdc, _messenger, _linkedAdapter, _owner) {
    FALLBACK_PROXY_ADMIN = new FallbackProxyAdmin(_usdc);
  }
  /* solhint-enable no-unused-vars */

  /*///////////////////////////////////////////////////////////////
                              MIGRATION
  ///////////////////////////////////////////////////////////////*/

  /**
   * @notice Initiates the process to migrate the bridged USDC to native USDC
   * @dev Full migration cant finish until L1 receives the message for setting the burn amount
   * @param _roleCaller The address that will be allowed to transfer the USDC roles
   * @param _setBurnAmountMinGasLimit Minimum gas limit that the setBurnAmount message can be executed on L1
   */
  function receiveMigrateToNative(address _roleCaller, uint32 _setBurnAmountMinGasLimit) external onlyLinkedAdapter {
    isMessagingDisabled = true;
    roleCaller = _roleCaller;

    // We need to do totalSupply + blacklistedFunds because on `receiveMessage` mint would fail causing the totalSupply to not increase
    // But the native token is still locked on L1
    uint256 _burnAmount = IUSDC(USDC).totalSupply() + blacklistedFunds;

    ICrossDomainMessenger(MESSENGER).sendMessage(
      LINKED_ADAPTER, abi.encodeWithSignature('setBurnAmount(uint256)', _burnAmount), _setBurnAmountMinGasLimit
    );

    emit MigratingToNative(MESSENGER, _roleCaller);
  }

  /**
   * @notice Transfers the USDC roles to the new owner
   * @param _owner The address to transfer ownership to
   * @dev Can only be called by the role caller set in the migration process
   */
  function transferUSDCRoles(address _owner) external {
    if (msg.sender != roleCaller) revert IOpUSDCBridgeAdapter_InvalidCaller();

    // Transfer ownership of the USDC contract to circle
    IUSDC(USDC).transferOwnership(_owner);

    // Transfer proxy admin ownership to the caller
    FALLBACK_PROXY_ADMIN.changeAdmin(msg.sender);
  }

  /*///////////////////////////////////////////////////////////////
                          MESSAGING CONTROL
  ///////////////////////////////////////////////////////////////*/

  /**
   * @notice Receive the stop messaging message from the linked adapter and stop outgoing messages
   */
  function receiveStopMessaging() external onlyLinkedAdapter {
    isMessagingDisabled = true;

    emit MessagingStopped(MESSENGER);
  }

  /**
   * @notice Resume messaging after it was stopped
   */
  function receiveResumeMessaging() external onlyLinkedAdapter {
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

    IUSDC(USDC).safeTransferFrom(msg.sender, address(this), _amount);

    // Burn the tokens
    IUSDC(USDC).burn(_amount);

    // Send the message to the linked adapter
    ICrossDomainMessenger(MESSENGER).sendMessage(
      LINKED_ADAPTER, abi.encodeWithSignature('receiveMessage(address,uint256)', _to, _amount), _minGasLimit
    );

    emit MessageSent(msg.sender, _to, _amount, MESSENGER, _minGasLimit);
  }

  /**
   * @notice Send signer tokens to other chain through the linked adapter
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
    bytes32 _messageHash =
      keccak256(abi.encode(address(this), block.chainid, _to, _amount, _deadline, userNonce[_signer]++));

    _checkSignature(_signer, _messageHash, _signature);

    IUSDC(USDC).safeTransferFrom(_signer, address(this), _amount);

    // Burn the tokens
    IUSDC(USDC).burn(_amount);

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
  function receiveMessage(address _user, uint256 _amount) external override onlyLinkedAdapter {
    // Mint the tokens to the user
    try IUSDC(USDC).mint(_user, _amount) {
      emit MessageReceived(_user, _amount, MESSENGER);
    } catch {
      blacklistedFunds += _amount;
      emit MessageFailed(_user, _amount);
    }
  }

  /*///////////////////////////////////////////////////////////////
                        BRIDGED USDC FUNCTIONS
  ///////////////////////////////////////////////////////////////*/

  /**
   * @notice Call with abitrary calldata on USDC contract.
   * @dev can't execute the following list of transactions:
   *  • transferOwnership (0xf2fde38b)
   *  • changeAdmin (0x8f283970)
   * @dev UpgradeTo and UpgradeToAndCall go through the fallback admin
   * @param _data The calldata to execute on the USDC contract
   */
  function callUsdcTransaction(bytes calldata _data) external onlyOwner {
    bytes4 _selector = bytes4(_data);
    bool _success;

    if (_selector == _TRANSFER_OWNERSHIP_SELECTOR || _selector == _CHANGE_ADMIN_SELECTOR) {
      revert IOpUSDCBridgeAdapter_ForbiddenTransaction();
    } else if (_selector == _UPGRADE_TO_SELECTOR || _selector == _UPGRADE_TO_AND_CALL_SELECTOR) {
      (_success,) = address(FALLBACK_PROXY_ADMIN).call(_data);
    } else {
      (_success,) = USDC.call(_data);
    }

    if (!_success) {
      revert IOpUSDCBridgeAdapter_InvalidTransaction();
    }

    emit USDCFunctionSent(_selector);
  }
}
