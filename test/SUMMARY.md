# Tests summary.

There are 4 main contracts, one abstract and 2 peripherals ones (lib, utils), total sloc is 379. Main implementation is built symmetrically - L1 and L2, with a factory/child pattern.

## Unit Tests
Current coverage is 100% of the branches for the 7 contracts, across 121 tests (all passing), except one branch flagged as non covered in the L1Adapter (a burn amount of 0, which should not revert) - manually reviewed as covered.
| File                                            | % Lines          | % Statements     | % Branches      | % Funcs         |
|-------------------------------------------------|------------------|------------------|-----------------|-----------------|
| src/contracts/L1OpUSDCBridgeAdapter.sol         | 100.00% (45/45)  | 100.00% (68/68)  | 95.83% (23/24)  | 100.00% (10/10) |
| src/contracts/L1OpUSDCFactory.sol               | 100.00% (12/12)  | 100.00% (17/17)  | 100.00% (2/2)   | 100.00% (2/2)   |
| src/contracts/L2OpUSDCBridgeAdapter.sol         | 100.00% (40/40)  | 100.00% (52/52)  | 100.00% (16/16) | 100.00% (10/10) |
| src/contracts/L2OpUSDCDeploy.sol                | 100.00% (26/26)  | 100.00% (40/40)  | 100.00% (4/4)   | 100.00% (3/3)   |
| src/contracts/universal/OpUSDCBridgeAdapter.sol | 100.00% (5/5)    | 100.00% (6/6)    | 100.00% (2/2)   | 100.00% (2/2)   |
| src/contracts/utils/FallbackProxyAdmin.sol      | 100.00% (4/4)    | 100.00% (4/4)    | 100.00% (0/0)   | 100.00% (4/4)   |
| src/libraries/CrossChainDeployments.sol         | 100.00% (25/25)  | 100.00% (26/26)  | 100.00% (16/16) | 100.00% (3/3)   |


## Integration Tests
The integration tests are implemented by switching between 3 different forks: mainnet, Optimism and Base. Crosschain messaging is achieved via the ICrossDomainMessenger contracts already deployed on the 3 chains (see IntegrationBase.sol).

The setup deploys the factory on mainnet, then proceed to deploy the L1 adapters and L2 factories and adapters on both Optimism and Base. Initial tests are conducted to both ensure deployment addresses never collide if there are multiple deployments on a given chain, as well as to ensure correct deployment on the multiple chains.

The rest of the integration tests are then conducted from/to mainnet to/from optimism only (given the reassurance of the functional equivalece based on the initial setup tests).

The following tests are conducted: 
- bridge usdc from mainnet to optimism (same or different address receiving the usdc.e, using the address of the sender or a message signed by it).
- bridge usdc from optimism to mainnet (same or different address receiving the usdc.e, using the address of the sender or a message signed by it).
- a sad-path where a signed message from mainnet to optimism fails to verify
- the same sad-path from optimism to mainner
- migrate to the native usdc
- stop and resuming the messaging from mainnet to optimism
- upgrade the usdc proxy on optimism (with or without triggering an additional call to the new implementation)
- update different privilegied roles in the L2 deployment (pauser, master minter, black lister, rescuer)

## Property Tests
We identified 19 properties before, during and after the implementation period. One became deprecated following additional refactor, leaving with 18 to tests.

### Fuzzing Campaign
We used Echidna to test these 18 properties. The setup runs entirely on the same chains, introducing 2 small differences with the real-life deployments: we use a mock bridge contract relaying every call received to another address atomically; the "L2" adapter has not the same address as its L1 counterpart (as they'd collide otherwise).

The 18 properties tested currently hold.

Limitations and future improvements:
- A more realistic implementation of the mock bridge should have a queue, executing transaction in fifo ordering
- The call generators should add additional constraints and post-conditions check, to have a more reliable test setup


### Formal Verification: Symbolic Execution
We used Halmos to test 6 of these properties. Properties not tested are either not easily challenged with symbolic execution (statefullness needed) or limited by Halmos itself (hitting loops in the implementation for instance).
