// // SPDX-License-Identifier: MIT
// pragma solidity 0.8.25;

// import {OpUSDCFactory} from 'contracts/OpUSDCFactory.sol';
// import {Test} from 'forge-std/Test.sol';
// import {IOpUSDCBridgeAdapter} from 'interfaces/IOpUSDCBridgeAdapter.sol';

// // contract TestL2OpUSDCBridgeAdapter is L2OpUSDCBridgeAdapter {
// //   constructor(
// //     address _usdc,
// //     address _messenger,
// //     address _linkedAdapter
// //   ) L2OpUSDCBridgeAdapter(_usdc, _messenger, _linkedAdapter) {}

// //   function setIsMessagingDisabled() external {
// //     isMessagingDisabled = true;
// //   }
// // }

// abstract contract Base is Test {
//   OpUSDCFactory public factory;

//   address internal _user = makeAddr('user');
//   address internal _usdc = makeAddr('USDC');
//   address internal _l1Messenger = makeAddr('l1Messenger');
//   address internal _l2Messenger = makeAddr('l2Messenger');
//   address internal _l1Adapter = makeAddr('l1Adapter');
//   address internal _l2Adapter = makeAddr('l2Adapter');

//   event MessageSent(address _user, uint256 _amount, uint32 _minGasLimit);
//   event MessageReceived(address _user, uint256 _amount);

//   function setUp() public virtual {
//     adapter = new TestL2OpUSDCBridgeAdapter(_usdc, _messenger, _linkedAdapter);
//   }
// }
