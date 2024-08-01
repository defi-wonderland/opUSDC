// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/Test.sol';
import {IL1OpUSDCFactory} from 'interfaces/IL1OpUSDCFactory.sol';

import {IOpUSDCBridgeAdapter} from 'interfaces/IOpUSDCBridgeAdapter.sol';
import {IUSDC} from 'interfaces/external/IUSDC.sol';
import {USDCInitTxs} from 'src/contracts/utils/USDCInitTxs.sol';

contract Bridge is Script {
  address public constant L1_MESSENGER = 0x58Cc85b8D04EA49cC6DBd3CbFFd00B4B8D6cb3ef;
  uint32 public constant MIN_GAS_LIMIT_DEPLOY = 9_000_000;
  string public constant CHAIN_NAME = 'Optimism Sepolia';
  IOpUSDCBridgeAdapter public immutable ADAPTER = IOpUSDCBridgeAdapter(0xF6277eD38fB97e0383927dc04fDEE397cd94124e);
  IUSDC public immutable USDC = IUSDC(0xF3dD0c89cf78C46A4150238e8A50285e1f4b5407);

  address public owner = vm.rememberKey(vm.envUint('SEPOLIA_PK'));

  function run() public {
    vm.startBroadcast(owner);
    uint256 _balanceOf = USDC.balanceOf(owner);
    ADAPTER.sendMessage(owner, _balanceOf, 200_000);
    vm.stopBroadcast();
  }
}
