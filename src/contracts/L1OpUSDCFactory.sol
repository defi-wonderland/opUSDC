// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {L2OpUSDCFactory} from 'contracts/L2OpUSDCFactory.sol';
import {AddressAliasHelper} from 'contracts/utils/AddressAliasHelper.sol';
import {CreateDeployer} from 'contracts/utils/CreateDeployer.sol';
import {USDCInitTxs} from 'contracts/utils/USDCInitTxs.sol';
import {IL1OpUSDCFactory} from 'interfaces/IL1OpUSDCFactory.sol';
import {ICreateX} from 'interfaces/external/ICreateX.sol';
import {IOptimismPortal} from 'interfaces/external/IOptimismPortal.sol';

import 'forge-std/Test.sol';

/**
 * @title L1OpUSDCFactory
 * @notice Factory contract to deploy and setup the `L1OpUSDCBridgeAdapter` contract on L1, the
 * `L2OpUSDCBridgeAdapter` and USDC proxy and implementation contracts on L2 on a single transaction.
 */
contract L1OpUSDCFactory is CreateDeployer, IL1OpUSDCFactory {
  /**
   * @inheritdoc IL1OpUSDCFactory
   */
  function deploy(DeployParams memory _params) external returns (DeploymentAddresses memory _deploymentAddresses) {
    // TODO: Check the l1 messenger is not already set

    // Calculate l1 adapter
    _deploymentAddresses.l1Adapter = computeCreate3Address(SALT, address(this));

    // Get this contract address on L2
    address _aliasedAddressThis = AddressAliasHelper.applyL1ToL2Alias(address(this));
    console.log('_aliasedAddressThis: ', _aliasedAddressThis);
    _deploymentAddresses.l2Factory = computeCreateAddress(_aliasedAddressThis, 0);

    // Get the l2 adapter address
    bytes memory _l2AdapterCArgs =
      abi.encode(_deploymentAddresses.l2UsdcProxy, _params.l2Messenger, _deploymentAddresses.l1Adapter);
    bytes memory _l2AdapterInitCode = bytes.concat(_params.l2AdapterCreationCode, _l2AdapterCArgs);
    // Precalculate linked adapter address on L2
    _deploymentAddresses.l2Adapter =
      computeCreate2Address(SALT, keccak256(_l2AdapterInitCode), _deploymentAddresses.l2Factory);

    // Get the l2 factory init code
    bytes memory _l2FactoryCreationCode = type(L2OpUSDCFactory).creationCode;
    bytes memory _l2FactoryCArgs =
      abi.encode(_l2AdapterInitCode, _params.usdcProxyCreationCode, _params.usdcImplementationCreationCode);
    bytes memory _l2FactoryInitCode = bytes.concat(_l2FactoryCreationCode, _l2FactoryCArgs);

    // Get the l2 usdc address
    _deploymentAddresses.l2UsdcImplementation =
      computeCreate2Address(SALT, keccak256(_params.usdcImplementationCreationCode), _deploymentAddresses.l2Factory);
    bytes memory _l2UsdcProxyInitCode =
      bytes.concat(_params.usdcProxyCreationCode, abi.encode(_deploymentAddresses.l2UsdcImplementation));
    _deploymentAddresses.l2UsdcProxy =
      computeCreate2Address(SALT, keccak256(_l2UsdcProxyInitCode), _deploymentAddresses.l2Factory);

    // Deploy the L1 adapter
    bytes memory _l1AdapterCArgs =
      abi.encode(_params.usdc, _params.l1Messenger, _deploymentAddresses.l2Adapter, _params.owner);
    bytes memory _l1AdapterInitCode = bytes.concat(_params.l1AdapterCreationCode, _l1AdapterCArgs);
    deployCreate3(SALT, _l1AdapterInitCode);

    console.log(4);

    // Deploy L2 op usdc factory through portal
    _params.portal.depositTransaction(address(0), 0, _params.minGasLimit, true, _l2FactoryInitCode);

    console.log(5);
    // console.log('gas left: ', gasleft());

    // L2OpUSDCFactory _jaja = new L2OpUSDCFactory(
    //   _deploymentAddresses.l1Adapter,
    //   _l2AdapterInitCode,
    //   _params.usdcProxyCreationCode,
    //   _params.usdcImplementationCreationCode
    // );

    // console.log('gas left: ', gasleft());
    // console.log(6);
    // console.log('jaja address: ', address(_jaja));
  }

  // /**
  //  * @inheritdoc IL1OpUSDCFactory
  //  */
  // function deploy2(DeployParams memory _params) external returns (DeploymentAddresses memory _deploymentAddresses) {
  //   // Declare vars outter and define them in an inner block scoper to avoid stack too deep error
  //   bytes memory _usdcImplementationDeployTx;
  //   bytes memory _usdcDeployProxyTx;
  //   bytes memory _l2AdapterDeployTx;
  //   {
  //     // Deploy usdc implementation on l2 tx
  //     _usdcImplementationDeployTx =
  //       abi.encodeWithSignature('deployCreate2(bytes32,bytes)', SALT, _params.usdcImplementationCreationCode);
  //     // Precalculate usdc implementation address on l2
  //     _deploymentAddresses.l2UsdcImplementation = CREATEX.computeCreate2Address(
  //       _guardedSaltL2, keccak256(_params.usdcImplementationCreationCode), address(CREATEX)
  //     );

  //     // Deploy usdc on L2 tx
  //     bytes memory _usdcProxyInitCode =
  //       bytes.concat(_params.usdcProxyCreationCode, abi.encode(_deploymentAddresses.l2UsdcImplementation));
  //     _usdcDeployProxyTx = abi.encodeWithSignature('deployCreate2(bytes32,bytes)', SALT, _usdcProxyInitCode);
  //     // Precalculate token address on l2
  //     _deploymentAddresses.l2UsdcProxy =
  //       CREATEX.computeCreate2Address(_guardedSaltL2, keccak256(_usdcProxyInitCode), address(CREATEX));

  //     // Define the l1 linked adapter address inner block scope to avoid stack too deep error
  //     _deploymentAddresses.l1Adapter = CREATEX.computeCreate3Address(GUARDED_SALT_L1, address(CREATEX));

  //     // Deploy adapter on L2 tx
  //     bytes memory _l2AdapterCArgs =
  //       abi.encode(_deploymentAddresses.l2UsdcProxy, _params.l2Messenger, _deploymentAddresses.l1Adapter);
  //     bytes memory _l2AdapterInitCode = bytes.concat(_params.l2AdapterCreationCode, _l2AdapterCArgs);
  //     _l2AdapterDeployTx = abi.encodeWithSignature('deployCreate2(bytes32,bytes)', SALT, _l2AdapterInitCode);
  //     // Precalculate linked adapter address on L2
  //     _deploymentAddresses.l2Adapter =
  //       CREATEX.computeCreate2Address(_guardedSaltL2, keccak256(_l2AdapterInitCode), address(CREATEX));
  //   }

  //   // Send the usdc and adapter deploy and initialization txs as messages to L2
  //   _params.l1Messenger.sendMessage(
  //     address(CREATEX), _usdcImplementationDeployTx, _params.minGasLimitUsdcImplementationDeploy
  //   );
  //   _params.l1Messenger.sendMessage(
  //     _deploymentAddresses.l2UsdcImplementation, USDCInitTxs.INITIALIZE, _params.minGasLimitInitTxs
  //   );
  //   _params.l1Messenger.sendMessage(
  //     _deploymentAddresses.l2UsdcImplementation, USDCInitTxs.INITIALIZEV2, _params.minGasLimitInitTxs
  //   );
  //   _params.l1Messenger.sendMessage(
  //     _deploymentAddresses.l2UsdcImplementation, USDCInitTxs.INITIALIZEV2_1, _params.minGasLimitInitTxs
  //   );
  //   _params.l1Messenger.sendMessage(
  //     _deploymentAddresses.l2UsdcImplementation, USDCInitTxs.INITIALIZEV2_2, _params.minGasLimitInitTxs
  //   );
  //   _params.l1Messenger.sendMessage(address(CREATEX), _usdcDeployProxyTx, _params.minGasLimitUsdcProxyDeploy);
  //   _params.l1Messenger.sendMessage(address(CREATEX), _l2AdapterDeployTx, _params.minGasLimitL2AdapterDeploy);

  //   // Deploy the L1 adapter
  //   bytes memory _l1AdapterCArgs = abi.encode(USDC, _params.l1Messenger, _deploymentAddresses.l2Adapter, _params.owner);
  //   bytes memory _l1AdapterInitCode = bytes.concat(_params.l1AdapterCreationCode, _l1AdapterCArgs);
  //   CREATEX.deployCreate3(SALT_L1, _l1AdapterInitCode);
  // }
}
