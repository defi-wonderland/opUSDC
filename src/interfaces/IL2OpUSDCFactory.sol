// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// solhint-disable func-name-mixedcase
interface IL2OpUSDCFactory {
  /*///////////////////////////////////////////////////////////////
                            STRUCTS
  ///////////////////////////////////////////////////////////////*/

  /**
   * @notice The struct to hold the USDC data for the name, symbol, currency, and decimals when initializing
   * @param _tokenName The name of the USDC token
   * @param _tokenSymbol The symbol of the USDC token
   * @param _tokenCurrency The currency that the USDC token represents
   * @param _tokenDecimals The number of decimals that the USDC token uses
   */
  struct USDCInitializeData {
    string _tokenName;
    string _tokenSymbol;
    string _tokenCurrency;
    uint8 _tokenDecimals;
  }

  /*///////////////////////////////////////////////////////////////
                            EVENTS
  ///////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when the USDC implementation is deployed
   * @param _l2UsdcImplementation The address of the L2 USDC implementation
   */
  event USDCImplementationDeployed(address _l2UsdcImplementation);

  /**
   * @notice Emitted when the USDC proxy is deployed
   * @param _l2UsdcProxy The address of the L2 USDC proxy
   */
  event USDCProxyDeployed(address _l2UsdcProxy);

  /**
   * @notice Emitted when the L2 adapter is deployed
   * @param _l2Adapter The address of the L2 adapter
   */
  event L2AdapterDeployed(address _l2Adapter);

  /**
   * @notice Emitted if a CREATE deployment fails
   */
  event CreateDeploymentFailed();

  /**
   * @notice Emitted when an USDC initialization tx failed
   * @param _index The index of the failed initialization tx
   * @dev First index will be hardcoded so index 1 is the start of the provided array
   */
  event InitializationFailed(uint256 _index);

  /**
   * @notice Emitted when configure minter fails
   * @param _minter The address of the minter
   */
  event ConfigureMinterFailed(address _minter);

  /**
   * @notice Emitted when update master minter fails
   * @param _newMasterMinter The address of the new master minter
   */
  event UpdateMasterMinterFailed(address _newMasterMinter);

  /**
   * @notice Emitted when transfer ownership fails
   * @param _newOwner The address of the new owner
   */
  event TransferOwnershipFailed(address _newOwner);

  /**
   * @notice Emitted when change admin fails
   * @param _newAdmin The address of the new admin
   */
  event ChangeAdminFailed(address _newAdmin);

  /*///////////////////////////////////////////////////////////////
                            ERRORS
  ///////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when the caller is not the L2 messenger, or the cross domain caller is not the L1 factory
   */
  error IL2OpUSDCFactory_InvalidSender();

  /**
   * @notice Thrown when a contract deployment fails
   */
  error IL2OpUSDCFactory_DeploymentFailed();

  /**
   * @notice Thrown when an USDC initialization tx failed
   * @param _txIndex The index of the failed initialization tx
   */
  error IL2OpUSDCFactory_InitializationFailed(uint256 _txIndex);

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  ///////////////////////////////////////////////////////////////*/

  /**
   * @notice Deploys the USDC implementation, proxy, and L2 adapter contracts all at once, and then initializes the USDC
   * @param _l1Adapter The address of the L1 adapter contract
   * @param _l2AdapterOwner The address of the L2 adapter owner
   * @param _usdcImplementationInitCode The creation code with the constructor arguments for the USDC implementation
   * @param _usdcInitializeData The USDC name, symbol, currency, and decimals used on the first `initialize()` call
   * @param _usdcInitTxs The initialization transactions for the USDC proxy and implementation contracts
   * @dev The USDC proxy owner needs to be set on the first init tx
   * @dev Using `CREATE` to guarantee that the addresses are unique among all the L2s
   */
  function deploy(
    address _l1Adapter,
    address _l2AdapterOwner,
    bytes memory _usdcImplementationInitCode,
    USDCInitializeData memory _usdcInitializeData,
    bytes[] memory _usdcInitTxs
  ) external;

  /*///////////////////////////////////////////////////////////////
                            VARIABLES
  ///////////////////////////////////////////////////////////////*/

  /**
   * @return _l2Messenger The address of the L2 messenger
   */
  function L2_MESSENGER() external view returns (address _l2Messenger);

  /**
   * @return _l1Factory The address of the L1 factory
   */
  function L1_FACTORY() external view returns (address _l1Factory);
}
