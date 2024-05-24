// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IL2OpUSDCFactory {
  error IL2OpUSDCBridgeAdapter_CreateDeploymentFailed();
  error IL2OpUSDCBridgeAdapter_UsdcInitializationFailed();
  error IL2OpUSDCBridgeAdapter_AdapterInitializationFailed();

  event DeployedUSDCProxy(address _usdcImplementation);
  event DeployedUSDCImpl(address _usdcProxy);
  event DeployedL2Adapter(address _l2Adapter);
}
