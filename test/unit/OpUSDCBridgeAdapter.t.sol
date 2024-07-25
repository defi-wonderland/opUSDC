// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {MessageHashUtils} from '@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol';
import {OpUSDCBridgeAdapter} from 'contracts/universal/OpUSDCBridgeAdapter.sol';
import {Test} from 'forge-std/Test.sol';
import {IOpUSDCBridgeAdapter} from 'interfaces/IOpUSDCBridgeAdapter.sol';
import {SigUtils} from 'test/utils/SigUtils.sol';

contract ForTestOpUSDCBridgeAdapter is OpUSDCBridgeAdapter {
  constructor(
    address _usdc,
    address _messenger,
    address _linkedAdapter,
    address _owner
  ) OpUSDCBridgeAdapter(_usdc, _messenger, _linkedAdapter, _owner) {}

  function receiveMessage(address _user, address _spender, uint256 _amount) external override {}

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
  address internal _signerAd;
  uint256 internal _signerPk;
  address internal _notSignerAd;
  uint256 internal _notSignerPk;
  address internal _messenger = makeAddr('messenger');

  function setUp() public virtual {
    (_signerAd, _signerPk) = makeAddrAndKey('signer');
    adapter = new ForTestOpUSDCBridgeAdapter(_usdc, _messenger, _linkedAdapter, _owner);
  }
}

contract OpUSDCBridgeAdapter_Unit_Constructor is Base {
  /**
   * @notice Check that the constructor works as expected
   */
  function test_constructorParams() public view {
    assertEq(adapter.USDC(), _usdc, 'USDC should be set to the provided address');
    assertEq(adapter.LINKED_ADAPTER(), _linkedAdapter, 'Linked adapter should be set to the provided address');
    assertEq(adapter.owner(), _owner, 'Owner should be set to the provided address');
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
    adapter.receiveMessage(address(0), address(0), 0);
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
  function test_validSignature(IOpUSDCBridgeAdapter.BridgeMessage memory _message) public {
    SigUtils _sigUtils = new SigUtils(address(adapter));

    vm.startPrank(_signerAd);
    bytes32 _hashedMessage = _sigUtils.getBridgeMessageHash(_message);
    bytes32 _digest = _sigUtils.getTypedBridgeMessageHash(_message);
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
