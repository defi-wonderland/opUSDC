// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IL2OpUSDCFactory {
  error IL2OpUSDCFactory_CreateDeploymentFailed();
  error IL2OpUSDCFactory_UsdcInitializationFailed();
  error IL2OpUSDCFactory_AdapterInitializationFailed();

  event DeployedUSDCImpl(address _usdcImplementation);
  event DeployedUSDCProxy(address _usdcProxy);
  event DeployedL2Adapter(address _l2Adapter);
}
