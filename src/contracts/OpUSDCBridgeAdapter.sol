// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IXERC20Lockbox} from 'interfaces/external/IXERC20Lockbox.sol';
import {IXERC20} from 'interfaces/external/IXERC20.sol';
import {ICrossDomainMessenger} from 'interfaces/external/ICrossDomainMessenger.sol';
import {IOpUSDCBridgeAdapter} from 'interfaces/IOpUSDCBridgeAdapter.sol';

contract OpUSDCBridgeAdapter is IOpUSDCBridgeAdapter {
  /// @inheritdoc IOpUSDCBridgeAdapter
  address public immutable BRIDGED_USDC;

  address public immutable L1_USDC;

  /// @inheritdoc IOpUSDCBridgeAdapter
  address public immutable LOCKBOX;

  /// @inheritdoc IOpUSDCBridgeAdapter
  address public immutable MESSENGER;

  /// @inheritdoc IOpUSDCBridgeAdapter
  address public linkedAdapter;

  /**
   * @notice Construct the OpUSDCBridgeAdapter contract
   * @dev On L2 the _lockbox param should be address(0)
   * @param _bridgedUSDC The address of the Bridged USDC contract
   * @param _l1USDC The address of the L1 USDC contract
   * @param _lockbox The address of the lockbox contract
   * @param _messenger The address of the messenger contract
   */
  constructor(address _bridgedUSDC, address _l1USDC, address _lockbox, address _messenger) {
    BRIDGED_USDC = _bridgedUSDC;
    LOCKBOX = _lockbox;
    MESSENGER = _messenger;
    L1_USDC = _l1USDC;
  }

  /**
   * @notice Set the linked adapter
   * @dev Only the owner can call this function
   * @param _linkedAdapter The address of the linked adapter
   */
  function setLinkedAdapter(address _linkedAdapter) external {
    if (msg.sender != Ownable(BRIDGED_USDC).owner()) revert IOpUSDCBridgeAdapter_NotTokenIssuer();

    linkedAdapter = _linkedAdapter;
    emit LinkedAdapterSet(_linkedAdapter);
  }

  /**
   * @notice Send the message to the linked adapter to mint the bridged representation on the linked chain
   * @param _isCanonical Whether the user is using the canonical USDC or the bridged representation
   * @param _amount The amount of tokens to send
   * @param _minGasLimit Minimum gas limit that the message can be executed with
   */
  function send(bool _isCanonical, uint256 _amount, uint32 _minGasLimit) external {
    if (linkedAdapter == address(0)) revert IOpUSDCBridgeAdapter_LinkedAdapterNotSet();

    if (_isCanonical) {
      if (LOCKBOX == address(0)) revert IOpUSDCBridgeAdapter_OnlyOnL1();

      // Transfer the tokens to the lockbox to mint the bridged representation
      IERC20(L1_USDC).transferFrom(msg.sender, address(this), _amount);
      IXERC20Lockbox(LOCKBOX).deposit(_amount);
    } else {
      // If not canonical transfer the bridged representation to this address from the user
      IERC20(BRIDGED_USDC).transferFrom(msg.sender, address(this), _amount);
    }

    // Burn the tokens that we received from the lockbox
    IXERC20(BRIDGED_USDC).burn(address(this), _amount);

    // Send the message to the linked adapter
    ICrossDomainMessenger(MESSENGER).sendMessage(
      linkedAdapter, abi.encodeWithSignature('receiveMessage(address,uint256)', msg.sender, _amount), _minGasLimit
    );

    emit MessageSent(msg.sender, _amount, _minGasLimit);
  }

  /**
   * @notice Receive the message from the other chain and mint the bridged representation for the user
   * @dev This function should only be called when receiving a message to mint the bridged representation
   * @param _user The user to mint the bridged representation for
   * @param _amount The amount of tokens to mint
   */
  function receiveMessage(address _user, uint256 _amount) external {
    if (linkedAdapter == address(0)) revert IOpUSDCBridgeAdapter_LinkedAdapterNotSet();
    if (msg.sender != MESSENGER || ICrossDomainMessenger(MESSENGER).xDomainMessageSender() != linkedAdapter) {
      revert IOpUSDCBridgeAdapter_NotLinkedAdapter();
    }

    // Mint the bridged representation for the user
    IXERC20(BRIDGED_USDC).mint(address(this), _amount);

    // If we are on L1 withdraw from the lockbox otherwise just transfer the bridged token to the user
    if (LOCKBOX != address(0)) {
      IXERC20Lockbox(LOCKBOX).withdrawTo(_user, _amount);
    } else {
      IERC20(BRIDGED_USDC).transfer(_user, _amount);
    }

    emit MessageRecieved(_user, _amount);
  }
}
