// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IntegrationBase} from './IntegrationBase.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';

contract dummyImplementation {
  address public minter;

  function configureMinter(address _minter) external {
    minter = _minter;
  }
}

contract Integration_PermissionedUsdcFlows is IntegrationBase {
  address internal _notOwner = makeAddr('notOwner');
  address internal _newImplementation = makeAddr('newImplementation');

  function setUp() public override {
    super.setUp();

    // Select the Optimism fork
    vm.selectFork(optimism);
  }

  /**
   * @notice Test `upgradeTo` USDC function on L2
   */
  function test_UpgradeTo() public {
    // Setup necessary data
    vm.etch(_newImplementation, 'Legit code');
    bytes memory _calldata = abi.encodeWithSignature('upgradeTo(address)', _newImplementation);

    vm.startPrank(_notOwner);
    // Call `upgradeTo` function from a not owner address
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _notOwner));
    l2Adapter.callUsdcTransaction(_calldata);

    // Use L2OpUSDCBridgeAdapter owner to call `upgradeTo` function through the adapter
    vm.startPrank(_owner);

    // Call `upgradeTo` function
    l2Adapter.callUsdcTransaction(_calldata);

    // Check that the USDC implementation has been upgraded
    assertEq(bridgedUSDC.implementation(), _newImplementation);
  }

  /**
   * @notice Test `upgradeToAndCall` USDC function on L2
   */
  function test_UpgradeToAndCall() public {
    // Setup necessary data
    _newImplementation = address(new dummyImplementation());
    bytes memory _functionToCall = abi.encodeWithSignature('configureMinter(address)', _notOwner);
    bytes memory _calldata =
      abi.encodeWithSignature('upgradeToAndCall(address,bytes)', _newImplementation, _functionToCall);

    vm.startPrank(_notOwner);
    // Call `upgradeToAndCall` function from a not owner address
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _notOwner));
    l2Adapter.callUsdcTransaction(_calldata);

    // Use L2OpUSDCBridgeAdapter owner to call `upgradeToAndCall` function through the adapter
    vm.startPrank(_owner);

    // Call `upgradeToAndCall` function
    l2Adapter.callUsdcTransaction(_calldata);

    // Check that the USDC implementation has been upgraded
    assertEq(bridgedUSDC.implementation(), _newImplementation);
  }
}
