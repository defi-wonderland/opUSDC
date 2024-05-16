// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {USDCInitTxs} from 'contracts/utils/USDCInitTxs.sol';
import {IOpUSDCFactory} from 'interfaces/IOpUSDCFactory.sol';
import {ICreateX} from 'interfaces/external/ICreateX.sol';

/**
 * @title OpUSDCFactory
 * @notice Factory contract to deploy and setup the `L1OpUSDCBridgeAdapter` contract on L1, the
 * `L2OpUSDCBridgeAdapter` and USDC proxy and implementation contracts on L2 on a single transaction.
 */
contract OpUSDCFactory is IOpUSDCFactory {
  /**
   * @inheritdoc IOpUSDCFactory
   */
  bytes32 public constant REDEPLOY_PROTECTION_BYTE = bytes32(uint256(0x01) << (88));

  /**
   * @inheritdoc IOpUSDCFactory
   */
  address public immutable USDC;

  /**
   * @inheritdoc IOpUSDCFactory
   */
  ICreateX public immutable CREATEX;

  /**
   * @inheritdoc IOpUSDCFactory
   */
  bytes32 public immutable SALT_L1;

  /**
   * @inheritdoc IOpUSDCFactory
   */
  bytes32 public immutable GUARDED_SALT_L1;

  /**
   * @param _usdc The address of the USDC contract
   * @param _createX The CreateX contract
   * @param _salt The random value to be used when calculating the salt for the factory deployment
   */
  constructor(address _usdc, address _createX, uint256 _salt) {
    USDC = _usdc;
    CREATEX = ICreateX(_createX);
    SALT_L1 = _parseSalt(address(this), _salt);
    GUARDED_SALT_L1 = _getGuardedSalt(address(this), block.chainid, SALT_L1);
  }

  /**
   * @inheritdoc IOpUSDCFactory
   */
  function deploy(DeployParams memory _params) external returns (DeploymentAddresses memory _deploymentAddresses) {
    // Declare vars outter and define them in an inner block scoper to avoid stack too deep error
    bytes memory _usdcImplementationDeployTx;
    bytes memory _usdcDeployProxyTx;
    bytes memory _l2AdapterDeployTx;
    {
      // Get the SALT_L1 for L2 deployment and calculate its guarded salt
      bytes32 _saltL2 = _parseSalt(_params.l2Messenger, uint256(SALT_L1));
      bytes32 _guardedSaltL2 = _getGuardedSalt(_params.l2Messenger, _params.l2ChainId, _saltL2);

      // Deploy usdc implementation on l2 tx
      _usdcImplementationDeployTx =
        abi.encodeWithSignature('deployCreate2(bytes32,bytes)', _saltL2, _params.usdcImplementationCreationCode);
      // Precalculate usdc implementation address on l2
      _deploymentAddresses.l2UsdcImplementation = CREATEX.computeCreate2Address(
        _guardedSaltL2, keccak256(_params.usdcImplementationCreationCode), address(CREATEX)
      );

      // Deploy usdc on L2 tx
      bytes memory _usdcProxyInitCode =
        bytes.concat(_params.usdcProxyCreationCode, abi.encode(_deploymentAddresses.l2UsdcImplementation));
      _usdcDeployProxyTx = abi.encodeWithSignature('deployCreate2(bytes32,bytes)', _saltL2, _usdcProxyInitCode);
      // Precalculate token address on l2

      address _l2Usdc = CREATEX.computeCreate2Address(_guardedSaltL2, keccak256(_usdcProxyInitCode), address(CREATEX));

      // Define the l1 linked adapter address inner block scope to avoid stack too deep error
      _deploymentAddresses.l1Adapter = CREATEX.computeCreate3Address(GUARDED_SALT_L1, address(CREATEX));

      // Deploy adapter on L2 tx
      bytes memory _l2AdapterCArgs = abi.encode(_l2Usdc, _params.l2Messenger, _deploymentAddresses.l1Adapter);
      bytes memory _l2AdapterInitCode = bytes.concat(_params.l2AdapterCreationCode, _l2AdapterCArgs);
      _l2AdapterDeployTx = abi.encodeWithSignature('deployCreate2(bytes32,bytes)', _saltL2, _l2AdapterInitCode);
      // Precalculate linked adapter address on L2
      _deploymentAddresses.l2Adapter =
        CREATEX.computeCreate2Address(_guardedSaltL2, keccak256(_l2AdapterInitCode), address(CREATEX));
    }

    // Send the usdc and adapter deploy and initialization txs as messages to L2
    _params.l1Messenger.sendMessage(
      address(CREATEX), _usdcImplementationDeployTx, _params.minGasLimitUsdcImplementationDeploy
    );
    _params.l1Messenger.sendMessage(
      _deploymentAddresses.l2UsdcImplementation, USDCInitTxs.INITIALIZE, _params.minGasLimitInitTxs
    );
    _params.l1Messenger.sendMessage(
      _deploymentAddresses.l2UsdcImplementation, USDCInitTxs.INITIALIZEV2, _params.minGasLimitInitTxs
    );
    _params.l1Messenger.sendMessage(
      _deploymentAddresses.l2UsdcImplementation, USDCInitTxs.INITIALIZEV2_1, _params.minGasLimitInitTxs
    );
    _params.l1Messenger.sendMessage(
      _deploymentAddresses.l2UsdcImplementation, USDCInitTxs.INITIALIZEV2_2, _params.minGasLimitInitTxs
    );
    _params.l1Messenger.sendMessage(address(CREATEX), _usdcDeployProxyTx, _params.minGasLimitUsdcProxyDeploy);
    _params.l1Messenger.sendMessage(address(CREATEX), _l2AdapterDeployTx, _params.minGasLimitL2AdapterDeploy);

    // Deploy the L1 adapter
    bytes memory _l1AdapterCArgs = abi.encode(USDC, _params.l1Messenger, _deploymentAddresses.l2Adapter, _params.owner);
    bytes memory _l1AdapterInitCode = bytes.concat(_params.l1AdapterCreationCode, _l1AdapterCArgs);
    CREATEX.deployCreate3(SALT_L1, _l1AdapterInitCode);
  }

  /**
   * @notice Parses the salt to get a more secure and unique one while interacting with CreateX
   * @dev Implement a safeguarding mechanism to implement a permissioned deploy protection to prevent cross-chain
   * re-deployments to the same address with the same salt but from a different sender
   * @param _sender The sender that triggers the CreateX deployment transaction
   * @param _salt The salt to be used for the deployment
   * @return _parsedSalt The parsed salt
   */
  function _parseSalt(address _sender, uint256 _salt) internal pure returns (bytes32 _parsedSalt) {
    bytes32 _senderToBytes = bytes32(uint256(uint160(_sender)) << 96);
    // Mask the given salt to take only the last 12 bytes and prevent it from interfering with the address part
    bytes32 _maskedSalt = bytes32(_salt & 0x000000000000000000000000000000000000000000ffffffffffffffffffff);
    // Tamper the salt with the address of the contract
    _parsedSalt = _senderToBytes | REDEPLOY_PROTECTION_BYTE | _maskedSalt;
  }

  /**
   * @notice Get the guarded salt for the deployment
   * @dev CreateX applies more entropy to the given salt depending on the input received. Since our salt will be one
   * with safeguarding mechanisms, we can calculate the guarded salt in a deterministic way.
   * @dev Since CreateX uses the guarded salt to deploy, we need to calculate it for precalculating the addresses that
   *  it will deploy
   * @param _sender The sender that triggers the CreateX deployment transaction
   * @param _chainId The chain id of the deployment
   * @param _salt The salt to be used for the deployment
   * @return _guardedSalt The guarded salt
   */
  function _getGuardedSalt(
    address _sender,
    uint256 _chainId,
    bytes32 _salt
  ) internal pure returns (bytes32 _guardedSalt) {
    _guardedSalt = keccak256(abi.encode(_sender, _chainId, _salt));
  }
}
