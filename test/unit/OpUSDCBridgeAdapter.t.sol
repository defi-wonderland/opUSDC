// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC1967Proxy} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import {MessageHashUtils} from '@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol';
import {OpUSDCBridgeAdapter} from 'contracts/universal/OpUSDCBridgeAdapter.sol';
import {Test} from 'forge-std/Test.sol';
import {IOpUSDCBridgeAdapter} from 'interfaces/IOpUSDCBridgeAdapter.sol';

contract ForTestOpUSDCBridgeAdapter is OpUSDCBridgeAdapter {
  constructor(
    address _usdc,
    address _messenger,
    address _linkedAdapter
  ) OpUSDCBridgeAdapter(_usdc, _messenger, _linkedAdapter) {}

  function receiveMessage(address _user, uint256 _amount) external override {}

  function sendMessage(address _to, uint256 _amount, uint32 _minGasLimit) external override {}

  function withdrawBlacklistedFunds(address _user) external override {}

  function sendMessage(
    address _signer,
    address _to,
    uint256 _amount,
    bytes calldata _signature,
    uint256 _nonce,
    uint256 _deadline,
    uint32 _minGasLimit
  ) external override {}

  function forTest_checkSignature(address _signer, bytes32 _messageHash, bytes memory _signature) public view {
    _checkSignature(_signer, _messageHash, _signature);
  }
}

abstract contract Base is Test {
  ForTestOpUSDCBridgeAdapter public adapter;

  address internal _usdc = makeAddr('opUSDC');
  address internal _owner = makeAddr('owner');
  address internal _linkedAdapter = makeAddr('linkedAdapter');
  address internal _messenger = makeAddr('messenger');
  address internal _adapterImpl;
  address internal _signerAd;
  uint256 internal _signerPk;
  address internal _notSignerAd;
  uint256 internal _notSignerPk;

  function setUp() public virtual {
    (_signerAd, _signerPk) = makeAddrAndKey('signer');
    _adapterImpl = address(new ForTestOpUSDCBridgeAdapter(_usdc, _messenger, _linkedAdapter));
    adapter = ForTestOpUSDCBridgeAdapter(
      address(new ERC1967Proxy(_adapterImpl, abi.encodeCall(OpUSDCBridgeAdapter.initialize, _owner)))
    );
  }
}

contract OpUSDCBridgeAdapter_Unit_Constructor is Base {
  /**
   * @notice Check that the constructor works as expected
   */
  function test_constructorParams() public view {
    assertEq(adapter.USDC(), _usdc, 'USDC should be set to the provided address');
    assertEq(adapter.MESSENGER(), _messenger, 'Messenger should be set to the provided address');
    assertEq(adapter.LINKED_ADAPTER(), _linkedAdapter, 'Linked adapter should be set to the provided address');
  }
}

contract OpUSDCBridgeAdapter_Unit_Initialize is Base {
  error InvalidInitialization();

  /**
   * @notice Check that the initialize function works as expected
   * @dev Needs to be checked on the proxy since the initialize function is disabled on the implementation
   */
  function test_initialize(address _owner) public {
    // Deploy a proxy contract setting the , and call the initialize function on it to set the owner
    ForTestOpUSDCBridgeAdapter _newAdapter = ForTestOpUSDCBridgeAdapter(
      address(new ERC1967Proxy(address(_adapterImpl), abi.encodeCall(OpUSDCBridgeAdapter.initialize, _owner)))
    );

    // Assert
    assertEq(_newAdapter.owner(), _owner, 'Owner should be set to the provided address');
  }
  /**
   * @notice Check that the initialize function reverts if it was already called
   */

  function test_revertIfAlreadyInitialize(address _sender, address _owner) public {
    // Expect revert with `InvalidInitialization` error
    vm.expectRevert(InvalidInitialization.selector);

    // Execute
    vm.prank(_sender);
    adapter.initialize(_owner);
  }
}

contract OpUSDCBridgeAdapter_Unit_SendMessage is Base {
  /**
   * @notice Execute vitual function to get 100% coverage
   */
  function test_doNothing() public {
    // Execute
    adapter.sendMessage(address(0), 0, 0);
  }
}

contract OpUSDCBridgeAdapter_Unit_SendMessageWithSignature is Base {
  /**
   * @notice Execute vitual function to get 100% coverage
   */
  function test_doNothing() public {
    // Execute
    adapter.sendMessage(address(0), address(0), 0, '', 0, 0, 0);
  }
}

contract ForTestOpUSDCBridgeAdapter_Unit_ReceiveMessage is Base {
  /**
   * @notice Execute vitual function to get 100% coverage
   */
  function test_doNothing() public {
    // Execute
    adapter.receiveMessage(address(0), 0);
  }
}

contract OpUSDCBridgeAdapter_Unit_CancelSignature is Base {
  function test_setNonceAsUsed(address _caller, uint256 _nonce) public {
    // Execute
    vm.prank(_caller);
    adapter.cancelSignature(_nonce);

    // Assert
    assertEq(adapter.userNonces(_caller, _nonce), true, 'Nonce should be set as used');
  }
}

contract OpUSDCBridgeAdapter_Unit_CheckSignature is Base {
  /**
   * @notice Check that the signature is valid
   */
  function test_validSignature(bytes memory _message) public {
    vm.startPrank(_signerAd);
    bytes32 _hashedMessage = keccak256(abi.encodePacked(_message));
    bytes32 _digest = MessageHashUtils.toEthSignedMessageHash(_hashedMessage);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(_signerPk, _digest);
    bytes memory _signature = abi.encodePacked(r, s, v);
    vm.stopPrank();
    // Execute
    adapter.forTest_checkSignature(_signerAd, _hashedMessage, _signature);
  }

  /**
   * @notice Check that the signature is invalid
   */
  function test_invalidSignature(bytes memory _message, string memory _notSigner) public {
    (_notSignerAd, _notSignerPk) = makeAddrAndKey(_notSigner);
    vm.assume(_signerPk != _notSignerPk);
    bytes32 _hashedMessage = keccak256(abi.encodePacked(_message));
    bytes32 _digest = MessageHashUtils.toEthSignedMessageHash(_hashedMessage);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(_notSignerPk, _digest);
    bytes memory _signature = abi.encodePacked(r, s, v);

    // Execute
    vm.expectRevert(abi.encodeWithSelector(IOpUSDCBridgeAdapter.IOpUSDCBridgeAdapter_InvalidSignature.selector));
    adapter.forTest_checkSignature(_signerAd, _hashedMessage, _signature);
  }
}
