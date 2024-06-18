// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IntegrationBase} from './IntegrationBase.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {IL2OpUSDCBridgeAdapter} from 'interfaces/IL2OpUSDCBridgeAdapter.sol';

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

    // TODO: ---> Remove after PR #44 is merged
    vm.startPrank(address(1));
    bridgedUSDC.transferOwnership(address(l2Adapter));
    // <----- Remove after PR #44 is merged

    // Select the Optimism fork
    vm.selectFork(optimism);
  }

  /**
   * @notice Test `transferOwnership` USDC function on L2 can not be called by l2 adapterowner
   */
  function test_TransferOwnership() public {
    // Setup necessary data
    bytes memory _calldata = abi.encodeWithSignature('transferOwnership(address)', _notOwner);

    // Use L2OpUSDCBridgeAdapter owner to call `transferOwnership` function through the adapter
    vm.startPrank(_owner);

    // Call `transferOwnership` function
    // solhint-disable-next-line max-line-length
    vm.expectRevert(abi.encodeWithSelector(IL2OpUSDCBridgeAdapter.IL2OpUSDCBridgeAdapter_ForbiddenTransaction.selector));
    l2Adapter.callUsdcTransaction(_calldata);
  }

  /**
   * @notice Test `changeAdmin` USDC function on L2 can not be called by l2 adapterowner
   */
  function test_ChangeAdmin() public {
    // Setup necessary data
    bytes memory _calldata = abi.encodeWithSignature('changeAdmin(address)', _notOwner);

    // Use L2OpUSDCBridgeAdapter owner to call `changeAdmin` function through the adapter
    vm.startPrank(_owner);

    // Call `changeAdmin` function
    // solhint-disable-next-line max-line-length
    vm.expectRevert(abi.encodeWithSelector(IL2OpUSDCBridgeAdapter.IL2OpUSDCBridgeAdapter_ForbiddenTransaction.selector));
    l2Adapter.callUsdcTransaction(_calldata);
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
    assertEq(dummyImplementation(address(bridgedUSDC)).minter(), _notOwner);
  }

  /**
   * @notice Test `updatePauser` USDC function on L2
   */
  function test_UpdatePauser() public {
    // Setup necessary data
    bytes memory _calldata = abi.encodeWithSignature('updatePauser(address)', _notOwner);

    vm.startPrank(_notOwner);
    // Call `updatePauser` function from a not owner address
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _notOwner));
    l2Adapter.callUsdcTransaction(_calldata);

    // Use L2OpUSDCBridgeAdapter owner to call `updatePauser` function through the adapter
    vm.startPrank(_owner);

    // Call `updatePauser` function
    l2Adapter.callUsdcTransaction(_calldata);

    //Call pauser function to get the pauser
    (, bytes memory _data) = address(bridgedUSDC).call(abi.encodeWithSignature('pauser()'));

    //Get pauser from _data
    address _pauser = address(uint160(uint256(bytes32(_data))));

    // Check that the USDC pauser has been updated
    assertEq(_pauser, _notOwner);
  }

  /**
   * @notice Test `updateMasterMinter` USDC function on L2
   */
  function test_UpdateMasterMinter() public {
    // Setup necessary data
    bytes memory _calldata = abi.encodeWithSignature('updateMasterMinter(address)', _notOwner);

    vm.startPrank(_notOwner);
    // Call `updateMasterMinter` function from a not owner address
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _notOwner));
    l2Adapter.callUsdcTransaction(_calldata);

    // Use L2OpUSDCBridgeAdapter owner to call `updateMasterMinter` function through the adapter
    vm.startPrank(_owner);

    // Call `updateMasterMinter` function
    l2Adapter.callUsdcTransaction(_calldata);

    //Call masterMinter function to get the masterMinter
    (, bytes memory _data) = address(bridgedUSDC).call(abi.encodeWithSignature('masterMinter()'));

    //Get masterMinter from _data
    address _masterMinter = address(uint160(uint256(bytes32(_data))));

    // Check that the USDC masterMinter has been updated
    assertEq(_masterMinter, _notOwner);
  }

  /**
   * @notice Test `updateBlacklister` USDC function on L2
   */
  function test_UpdateBlacklister() public {
    // Setup necessary data
    bytes memory _calldata = abi.encodeWithSignature('updateBlacklister(address)', _notOwner);

    vm.startPrank(_notOwner);
    // Call `updateBlacklister` function from a not owner address
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _notOwner));
    l2Adapter.callUsdcTransaction(_calldata);

    // Use L2OpUSDCBridgeAdapter owner to call `updateBlacklister` function through the adapter
    vm.startPrank(_owner);

    // Call `updateBlacklister` function
    l2Adapter.callUsdcTransaction(_calldata);

    //Call blacklister function to get the blacklister
    (, bytes memory _data) = address(bridgedUSDC).call(abi.encodeWithSignature('blacklister()'));

    //Get blacklister from _data
    address _blacklister = address(uint160(uint256(bytes32(_data))));

    // Check that the USDC blacklister has been updated
    assertEq(_blacklister, _notOwner);
  }

  /**
   * @notice Test `updateRescuer` USDC function on L2
   */
  function test_UpdateRescuer() public {
    // Setup necessary data
    bytes memory _calldata = abi.encodeWithSignature('updateRescuer(address)', _notOwner);

    vm.startPrank(_notOwner);
    // Call `updateRescuer` function from a not owner address
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _notOwner));
    l2Adapter.callUsdcTransaction(_calldata);

    // Use L2OpUSDCBridgeAdapter owner to call `updateRescuer` function through the adapter
    vm.startPrank(_owner);

    // Call `updateRescuer` function
    l2Adapter.callUsdcTransaction(_calldata);

    //Call rescuer function to get the rescuer
    (, bytes memory _data) = address(bridgedUSDC).call(abi.encodeWithSignature('rescuer()'));

    //Get rescuer from _data
    address _rescuer = address(uint160(uint256(bytes32(_data))));

    // Check that the USDC rescuer has been updated
    assertEq(_rescuer, _notOwner);
  }
}
