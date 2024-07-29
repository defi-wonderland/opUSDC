# opUSDC

> ⚠️ This code has not been audited yet and is not production ready at this time, tread with caution.


opUSDC allows for an efficient and modular solution for expanding USDC across the optimism super chain ecosystem. Utilizing the cross chain messaging of the canonical bridge the adapter allows for easy access to USDC liquidity across all op chains. 

## Contracts

_`L1OpUSDCFactory.sol`_ - Factory contract to deploy and setup the `L1OpUSDCBridgeAdapter` contract on L1. Precalculates the addresses of the L2 deployments and triggers their deployment, by sending a transaction to L2.

_`L2OpUSDCDeploy.sol`_ - One time use deployer contract deployed from the L1 factory through a cross-chain deployment. Used as a utility contract for deploying the L2 USDC Proxy, and `L2OpUSDCBridgeAdapter` contract, all at once in its constructor.

_`L1OpUSDCBridgeAdapter`_ - Contract that allows for the transfer of USDC from Ethereum Mainnet to a specific OP-chain. Locks USDC on Ethereum Mainnet and sends a message to the other chain to mint the equivalent amount of USDC. Receives messages from the other chain and unlocks USDC on the Ethereum Mainnet. Controls the message flow between layers. Supports the requirements for the Bridged USDC to be migrated to Native USDC, should the chain operator and Circle want to.

_`L2OpUSDCBridgeAdapter`_ - Contract that allows for the transfer of USDC from the a specific OP-chain to Ethereum Mainnet. Burns USDC on the L2 and sends a message to Ethereum Mainnet to unlock the equivalent amount of USDC. Receives messages from Ethereum Mainnet and mints USDC. Allows chain operator to execute arbitrary functions on the Bridged USDC contract, as if he was the owner of the contract.

## L1 → L2 Deployment
![image](https://github.com/defi-wonderland/opUSDC/assets/165055168/ac9d0b57-03e7-40ae-b109-34d656d7539b)

## L1 → L2 USDC Canonical Bridging
![image](https://github.com/defi-wonderland/opUSDC/assets/165055168/eaf55522-e768-463f-830b-b9305cec1e79)

## Migrating from Bridged USDC to Native USDC
![image](https://github.com/defi-wonderland/opUSDC/assets/165055168/17aebc4a-709f-4084-ab83-000e299a70bd)

## Setup

1. Install Foundry by following the instructions from [their repository](https://github.com/foundry-rs/foundry#installation).
2. Copy the `.env.example` file to `.env` and fill in the variables.
3. Install the dependencies by running: `yarn install`. In case there is an error with the commands, run `foundryup` and try them again.

## Build

The default way to build the code is suboptimal but fast, you can run it via:

```bash
yarn build
```

In order to build a more optimized code ([via IR](https://docs.soliditylang.org/en/v0.8.15/ir-breaking-changes.html#solidity-ir-based-codegen-changes)), run:

```bash
yarn build:optimized
```

## Running tests

Unit tests should be isolated from any externalities, while Integration usually run in a fork of the blockchain. In this boilerplate you will find example of both.

In order to run both unit and integration tests, run:

```bash
yarn test
```

In order to just run unit tests, run:

```bash
yarn test:unit
```

In order to run unit tests and run way more fuzzing than usual (5x), run:

```bash
yarn test:unit:deep
```

In order to just run integration tests, run:

```bash
yarn test:integration
```

In order to check your current code coverage, run:

```bash
yarn coverage
```

## Licensing
The primary license for the boilerplate is MIT, see [`LICENSE`](https://github.com/defi-wonderland/opUSDC/blob/main/LICENSE)
