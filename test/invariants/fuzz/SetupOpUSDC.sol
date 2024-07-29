// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {EchidnaTest} from '../AdvancedTestsUtils.sol';
// https://github.com/crytic/building-secure-contracts/blob/master/program-analysis/echidna/advanced/testing-bytecode.md
import {L1OpUSDCBridgeAdapter} from 'contracts/L1OpUSDCBridgeAdapter.sol';
import {IL1OpUSDCFactory, L1OpUSDCFactory} from 'contracts/L1OpUSDCFactory.sol';
import {L2OpUSDCBridgeAdapter} from 'contracts/L2OpUSDCBridgeAdapter.sol';
import {IL2OpUSDCDeploy, L2OpUSDCDeploy} from 'contracts/L2OpUSDCDeploy.sol';
import {USDCInitTxs} from 'contracts/utils/USDCInitTxs.sol';
import {IUSDC} from 'interfaces/external/IUSDC.sol';
import {Create2Deployer} from 'test/invariants/fuzz/Create2Deployer.sol';
import {MockBridge} from 'test/invariants/fuzz/MockBridge.sol';
import {MockPortal} from 'test/invariants/fuzz/MockPortal.sol';
import {USDC_IMPLEMENTATION_CREATION_CODE} from 'test/utils/USDCImplementationCreationCode.sol';

// solhint-disable
contract SetupOpUSDC is EchidnaTest {
  string public constant CHAIN_NAME = 'Optimism';
  string internal constant _NAME = 'OpUSDCBridgeAdapter';
  string internal constant _VERSION = '1.0.0';

  IUSDC usdcMainnet;
  IUSDC usdcBridged;

  bytes32 internal _salt = keccak256(abi.encode(address(this)));
  address internal usdcBridgedImplementation;

  L1OpUSDCBridgeAdapter internal l1Adapter;
  L1OpUSDCFactory internal factory;

  L2OpUSDCBridgeAdapter internal l2Adapter;
  L2OpUSDCDeploy internal l2Factory;

  MockBridge internal mockMessenger;
  MockPortal internal mockPortal;
  Create2Deployer internal create2Deployer;

  address internal _usdcMinter = address(uint160(uint256(keccak256('usdc.minter'))));

  /////////////////////////////////////////////////////////////////////
  //                          Initial setup                          //
  /////////////////////////////////////////////////////////////////////

  constructor() {
    IL1OpUSDCFactory.L2Deployments memory _l2Deployments = _mainnetSetup();
    _l2Setup(_l2Deployments);
    _setupUsdc();
  }

  function _setupUsdc() internal {
    hevm.prank(usdcMainnet.masterMinter());
    usdcMainnet.configureMinter(address(_usdcMinter), type(uint256).max);

    hevm.prank(usdcMainnet.masterMinter());
    usdcMainnet.configureMinter(address(l1Adapter), type(uint256).max); // Allow burning the locked supplye
  }

  // Deploy: USDC L1, factory L1, L1 adapter
  function _mainnetSetup() internal returns (IL1OpUSDCFactory.L2Deployments memory _l2Deployments) {
    address targetAddress;

    uint256 size = USDC_IMPLEMENTATION_CREATION_CODE.length;
    bytes memory _usdcBytecode = USDC_IMPLEMENTATION_CREATION_CODE;

    // Deploy USDC on "mainnet"
    assembly {
      targetAddress := create(0, add(_usdcBytecode, 0x20), size) // Skip the 32 bytes encoded length.
    }

    usdcMainnet = IUSDC(targetAddress);

    bytes[] memory usdcInitTxns = new bytes[](3);
    usdcInitTxns[0] = USDCInitTxs.INITIALIZEV2;
    usdcInitTxns[1] = USDCInitTxs.INITIALIZEV2_1;
    usdcInitTxns[2] = USDCInitTxs.INITIALIZEV2_2;

    factory = new L1OpUSDCFactory(address(usdcMainnet));

    //Deploy USDC implementation on L2
    assembly {
      targetAddress := create(0, add(_usdcBytecode, 0x20), size) // Skip the 32 bytes encoded length.
    }

    usdcBridgedImplementation = targetAddress;

    mockMessenger = MockBridge(0x4200000000000000000000000000000000000007);
    mockPortal = new MockPortal();
    mockMessenger.setPortalAddress(address(mockPortal));

    // owner is this contract, as managed in the _agents handler
    _l2Deployments = IL1OpUSDCFactory.L2Deployments(address(this), usdcBridgedImplementation, 9_000_000, usdcInitTxns);

    (address _l1Adapter, address _l2Factory, address _l2Adapter) =
      factory.deploy(address(mockMessenger), address(this), CHAIN_NAME, _l2Deployments);

    l2Factory = L2OpUSDCDeploy(_l2Factory);
    l1Adapter = L1OpUSDCBridgeAdapter(_l1Adapter);
    l2Adapter = L2OpUSDCBridgeAdapter(_l2Adapter);
  }

  // Send a (mock) message to the L2 messenger to deploy the L2 factory and the L2 adapter (which deploys usdc L2 too)
  function _l2Setup(IL1OpUSDCFactory.L2Deployments memory _l2Deployments) internal {
    IL2OpUSDCDeploy.USDCInitializeData memory usdcInitializeData = IL2OpUSDCDeploy.USDCInitializeData(
      string.concat(factory.USDC_NAME(), ' ', '(', CHAIN_NAME, ')'),
      factory.USDC_SYMBOL(),
      usdcMainnet.currency(),
      usdcMainnet.decimals()
    );

    bytes memory _l2factoryConstructorArgs = abi.encode(
      address(l1Adapter),
      _l2Deployments.l2AdapterOwner,
      _l2Deployments.usdcImplAddr,
      usdcInitializeData, // encode?
      _l2Deployments.usdcInitTxs // encodePacked?
    );

    bytes memory _l2FactoryInitCode = bytes.concat(type(L2OpUSDCDeploy).creationCode, _l2factoryConstructorArgs);

    // !!!! Nonce incremented to avoid collision !!!
    mockMessenger.relayMessage(
      mockMessenger.messageNonce() + 1,
      address(factory),
      factory.L2_CREATE2_DEPLOYER(),
      0,
      9_000_000,
      abi.encodeWithSignature('deploy(uint256,bytes32,bytes)', 0, factory.deploymentsSaltCounter(), _l2FactoryInitCode)
    );

    usdcBridged = IUSDC(l2Adapter.USDC());
  }
}
