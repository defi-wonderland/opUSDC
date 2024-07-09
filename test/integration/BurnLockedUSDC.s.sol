// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {L1OpUSDCBridgeAdapter} from 'contracts/L1OpUSDCBridgeAdapter.sol';
import {IL1OpUSDCFactory, L1OpUSDCFactory} from 'contracts/L1OpUSDCFactory.sol';
import {L2OpUSDCBridgeAdapter} from 'contracts/L2OpUSDCBridgeAdapter.sol';
import {L2OpUSDCFactory} from 'contracts/L2OpUSDCFactory.sol';
import {USDCInitTxs} from 'contracts/utils/USDCInitTxs.sol';

import {StdStorage, stdStorage} from 'forge-std/StdStorage.sol';
import {IL2OpUSDCFactory} from 'interfaces/IL2OpUSDCFactory.sol';
import {IUSDC} from 'interfaces/external/IUSDC.sol';

import {USDC_IMPLEMENTATION_CREATION_CODE} from 'script/utils/USDCImplementationCreationCode.sol';
import {AddressAliasHelper} from 'test/utils/AddressAliasHelper.sol';
import {Helpers} from 'test/utils/Helpers.sol';
import {ITestCrossDomainMessenger} from 'test/utils/interfaces/ITestCrossDomainMessenger.sol';

contract BurnLockedUSDC is Helpers {
  error GameNotInProgress();

  error OutOfOrderResolution();

  uint256 internal constant _SEPOLIA_FORK_BLOCK = 6_277_867;
  ITestCrossDomainMessenger public constant OPTIMISM_L1_MESSENGER =
    ITestCrossDomainMessenger(0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1);
  IPortal public constant OPTIMISM_PORTAL = IPortal(0x16Fc5058F25648194471939df75CF27A2fdC48BC);
  address public constant L1_ADAPTER = 0x3f69b39D80b7d8E0a76014D4e907FE7B43dAcFCf;
  address public constant L2_ADAPTER = 0x10aD0D43f1Fd537bfd075233030A1df2c23CfaB8;

  address internal _user = 0x8421D6D2253d3f8e25586Aa6692b1Bf591da3779;
  // OpUSDC Protocol
  L1OpUSDCBridgeAdapter public l1Adapter;
  L1OpUSDCFactory public l1Factory;
  L2OpUSDCFactory public l2Factory;
  L2OpUSDCBridgeAdapter public l2Adapter;
  IUSDC public bridgedUSDC;
  IL2OpUSDCFactory.USDCInitializeData public usdcInitializeData;
  IL1OpUSDCFactory.L2Deployments public l2Deployments;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('sepolia'), _SEPOLIA_FORK_BLOCK);
  }

  function test_finalizeBurnLockedUSDCMsg() public {
    vm.warp(block.timestamp + 30 days);

    // vm.expectEmit
    IDisputeGame.ProvenWithdrawal memory _tx = OPTIMISM_PORTAL.provenWithdrawals(
      0x2828ddaedac21f299204b7b108011a37a0a791c52a207c80d0ee72a26549c3ab, 0x8421D6D2253d3f8e25586Aa6692b1Bf591da3779
    );

    vm.prank(_user);
    _tx.disputeGameProxy.resolve();

    vm.prank(_user);
    OPTIMISM_PORTAL.finalizeWithdrawalTransaction(
      IPortal.WithdrawalTransaction({
        nonce: 1_766_847_064_778_384_329_583_297_500_742_918_515_827_483_896_875_618_958_121_606_201_292_623_649,
        sender: 0x4200000000000000000000000000000000000007,
        target: 0x58Cc85b8D04EA49cC6DBd3CbFFd00B4B8D6cb3ef,
        value: 0,
        gasLimit: 387_163,
        data: hex'd764ad0b0001000000000000000000000000000000000000000000000000000000000e8a00000000000000000000000010ad0d43f1fd537bfd075233030a1df2c23cfab80000000000000000000000003f69b39d80b7d8e0a76014d4e907fe7b43dacfcf000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000186a000000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000024cc43f3d3000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000'
      })
    );
  }
}

interface IPortal {
  function finalizeWithdrawalTransaction(WithdrawalTransaction memory _tx) external;

  function finalizeWithdrawalTransactionExternalProof(
    WithdrawalTransaction memory _tx,
    address _proofSubmitter
  ) external;

  function provenWithdrawals(
    bytes32 _withdrawalHash,
    address _proofSubmitter
  ) external returns (IDisputeGame.ProvenWithdrawal memory);

  struct WithdrawalTransaction {
    uint256 nonce;
    address sender;
    address target;
    uint256 value;
    uint256 gasLimit;
    bytes data;
  }
}

interface IDisputeGame {
  function resolve() external returns (GameStatus status_);

  struct ProvenWithdrawal {
    IDisputeGame disputeGameProxy;
    uint64 timestamp;
  }

  enum GameStatus {
    // The game is currently in progress, and has not been resolved.
    IN_PROGRESS,
    // The game has concluded, and the `rootClaim` was challenged successfully.
    CHALLENGER_WINS,
    // The game has concluded, and the `rootClaim` could not be contested.
    DEFENDER_WINS
  }
}
