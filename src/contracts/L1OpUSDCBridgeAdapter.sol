// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {OpUSDCBridgeAdapter} from 'contracts/universal/OpUSDCBridgeAdapter.sol';
import {IL1OpUSDCBridgeAdapter} from 'interfaces/IL1OpUSDCBridgeAdapter.sol';
import {ICrossDomainMessenger} from 'interfaces/external/ICrossDomainMessenger.sol';
import {IUSDC} from 'interfaces/external/IUSDC.sol';

contract L1OpUSDCBridgeAdapter is
  IL1OpUSDCBridgeAdapter,
  Initializable,
  OpUSDCBridgeAdapter,
  OwnableUpgradeable,
  UUPSUpgradeable
{
  using SafeERC20 for IUSDC;

  /// @inheritdoc IL1OpUSDCBridgeAdapter
  uint256 public burnAmount;

  /**
   * @notice Construct the OpUSDCBridgeAdapter contract
   * @param _usdc The address of the USDC Contract to be used by the adapter
   * @param _messenger The address of the messenger contract
   * @param _linkedAdapter The address of the linked adapter
   * @dev The constructor is only used to initialize the OpUSDCBridgeAdapter immutable variables
   */
  constructor(
    address _usdc,
    address _messenger,
    address _linkedAdapter
  ) OpUSDCBridgeAdapter(_usdc, _messenger, _linkedAdapter) {
    _disableInitializers();
  }

  /**
   * @notice Initialize the contract
   * @param initialOwner The address of the initial owner of the contract
   */
  function initialize(address initialOwner) external initializer {
    __Ownable_init(initialOwner);
  }

  /**
   * @notice Sets the amount of USDC tokens that will be burned when the burnLockedUSDC function is called
   * @param _amount The amount of USDC tokens that will be burned
   * @dev Only callable by the owner
   */
  function setBurnAmount(uint256 _amount) external onlyOwner {
    burnAmount = _amount;

    emit BurnAmountSet(_amount);
  }

  /**
   * @notice Burns the USDC tokens locked in the contract
   * @dev The amount is determined by the burnAmount variable, which is set in the setBurnAmount function
   */
  function burnLockedUSDC() external onlyOwner {
    // Burn the USDC tokens
    IUSDC(USDC).burn(address(this), burnAmount);

    // Set the burn amount to 0
    burnAmount = 0;
  }

  /**
   * @notice Send the message to the linked adapter to mint the bridged representation on the linked chain
   * @param _to The target address on the destination chain
   * @param _amount The amount of tokens to send
   * @param _minGasLimit Minimum gas limit that the message can be executed with
   */
  function sendMessage(address _to, uint256 _amount, uint32 _minGasLimit) external override {
    // Ensure messaging is enabled
    if (isMessagingDisabled) revert IOpUSDCBridgeAdapter_MessagingDisabled();

    // Transfer the tokens to the contract
    IUSDC(USDC).safeTransferFrom(msg.sender, address(this), _amount);

    // Send the message to the linked adapter
    ICrossDomainMessenger(MESSENGER).sendMessage(
      LINKED_ADAPTER, abi.encodeWithSignature('receiveMessage(address,uint256)', _to, _amount), _minGasLimit
    );

    emit MessageSent(msg.sender, _to, _amount, _minGasLimit);
  }

  /**
   * @notice Send a message to the linked adapter to upgrade the implementation of the contract
   * @param _newImplementation The address of the new implementation
   * @param _data The data to be used in the upgrade call
   * @param _minGasLimit Minimum gas limit that the message can be executed with
   */
  function sendUpgrade(address _newImplementation, bytes memory _data, uint32 _minGasLimit) external onlyOwner {
    ICrossDomainMessenger(MESSENGER).sendMessage(
      LINKED_ADAPTER,
      abi.encodeWithSignature('upgradeToAndCall(address,bytes)', _newImplementation, _data),
      _minGasLimit
    );
  }

  /**
   * @notice Receive the message from the other chain and transfer the tokens to the user
   * @dev This function should only be called when receiving a message to mint the bridged representation
   * @param _user The user to mint the bridged representation for
   * @param _amount The amount of tokens to mint
   */
  function receiveMessage(address _user, uint256 _amount) external override checkSender {
    // Transfer the tokens to the user
    IUSDC(USDC).safeTransfer(_user, _amount);

    emit MessageReceived(_user, _amount);
  }

  /**
   * @notice Send a message to the linked adapter to call receiveStopMessaging() and stop outgoing messages.
   * @dev Only callable by the owner of the adapter
   * @dev Setting isMessagingDisabled to true is an irreversible operation
   * @param _minGasLimit Minimum gas limit that the message can be executed with
   */
  function stopMessaging(uint32 _minGasLimit) external onlyOwner {
    // Ensure messaging is enabled
    if (isMessagingDisabled) revert IOpUSDCBridgeAdapter_MessagingDisabled();

    isMessagingDisabled = true;
    ICrossDomainMessenger(MESSENGER).sendMessage(
      LINKED_ADAPTER, abi.encodeWithSignature('receiveStopMessaging()'), _minGasLimit
    );
    emit MessagingStopped();
  }

  /**
   * @notice Authorize the upgrade of the implementation of the contract
   * @param newImplementation The address of the new implementation
   * @dev Only callable by the owner of the contract
   */
  function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
