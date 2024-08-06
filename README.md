# opUSDC

> ⚠️ This code has not been audited yet and is not production ready at this time, tread with caution.

opUSDC allows for an efficient and modular solution to expand USDC across the optimism super chain ecosystem. Utilizing the cross-chain messaging of the canonical bridge the adapter allows for easy access to USDC liquidity across all op chains.

## Contracts

_`L1OpUSDCFactory.sol`_ - Factory contract to deploy and setup the `L1OpUSDCBridgeAdapter` contract on L1. Precalculates the addresses of the L2 deployments and triggers their deployment, by sending a transaction to L2.

_`L2OpUSDCDeploy.sol`_ - One time use deployer contract deployed from the L1 factory through a cross-chain deployment. Used as a utility contract for deploying the L2 USDC Proxy, and `L2OpUSDCBridgeAdapter` contract, all at once in its constructor.

_`L1OpUSDCBridgeAdapter`_ - Contract that allows for the transfer of USDC from Ethereum Mainnet to a specific OP-chain. Locks USDC on Ethereum Mainnet and sends a message to the other chain to mint the equivalent amount of USDC. Receives messages from the other chain and unlocks USDC on the Ethereum Mainnet. Controls the message flow between layers. Supports the requirements for the Bridged USDC to be migrated to Native USDC should the chain operator and Circle want to.

_`L2OpUSDCBridgeAdapter`_ - Contract that allows for the transfer of USDC from the specific OP-chain to Ethereum Mainnet. Burns USDC on the L2 and sends a message to Ethereum Mainnet to unlock the equivalent amount of USDC. Receives messages from Ethereum Mainnet and mints USDC. Allows chain operator to execute arbitrary functions on the Bridged USDC contract as if they were the owner of the contract.

## L1 → L2 Deployment

![image](https://github.com/user-attachments/assets/1ec286f6-87ae-4b08-8086-ee8077a36ae3)

## L1 → L2 USDC Canonical Bridging

![image](https://github.com/defi-wonderland/opUSDC/assets/165055168/eaf55522-e768-463f-830b-b9305cec1e79)

## Migrating from Bridged USDC to Native USDC

![image](https://github.com/user-attachments/assets/291aae4c-e9fb-43a5-a11d-71bb3fc78311)


## Setup

1. Install Foundry by following the instructions from [their repository](https://github.com/foundry-rs/foundry#installation).
2. Copy the `.env.example` file to `.env` and fill in the variables.
3. Install the dependencies by running: `yarn install`. If there is an error with the commands, run `foundryup` and try them again.

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

Unit tests should be isolated from any externalities, while Integration tests usually run in a blockchain fork. In this boilerplate, you will find examples of both.

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

## Deploying

In order to deploy the opUSDC procotol for your op-chain, you will need to fill out these variables in the `.env` file:

```python
# The factory contract address on L1
L1_FACTORY_MAINNET=
# The bridged USDC implementation address on L2
BRIDGED_USDC_IMPLEMENTATION=
# The address of your CrossDomainMessenger on L1
L1_MESSENGER=
# The name of your chain
CHAIN_NAME=
# The private key that will sign the transactions on L1
MAINNET_PK=
# Ethereum RPC URL
MAINNET_RPC=
```

After all these variables are set, navigate to the `script/mainnet/Deploy.s.sol` file and edit the following lines with your desired configuration, we add a sanity check that will revert if you forget to change this value:
```solidity
    // NOTE: We have these hardcoded to default values, if used in product you will need to change them

    bytes[] memory _usdcInitTxs = new bytes[](3);
    
    _usdcInitTxs[0] = USDCInitTxs.INITIALIZEV2;
    _usdcInitTxs[1] = USDCInitTxs.INITIALIZEV2_1;
    _usdcInitTxs[2] = USDCInitTxs.INITIALIZEV2_2;

    // Sanity check to ensure the caller of this script changed this value to the proper naming
    assert(keccak256(_usdcInitTxs[0]) != keccak256(USDCInitTxs.INITIALIZEV2));
```

Then run this command to test:
```bash
yarn script:deploy
```

And when you are ready to deploy to mainnet, run:
```bash
yarn script:deploy:broadcast
```

## Migrating to Native USDC
> ⚠️ Migrating to native USDC is a manual process that requires communication with circle, this section assumes both parties are ready to migrate to native USDC.

In order to migrate to native USDC, you will need to fill out these variables in the `.env` file:
```python
# The address of the L1 opUSDC bridge adapter
L1_ADAPTER=
# The private key of the transaction signer, should be the owner of the L1 Adapter
MAINNET_OWNER_PK=
# The address of the role caller, should be provided by circle
ROLE_CALLER=
# The address of the burn caller, should be provided by circle
BURN_CALLER
```

After all these variables are set, run this command to test:
```bash
yarn script:migrate
```

And when you are ready to migrate to native USDC, run:
```bash
yarn script:migrate:broadcast
```

## Licensing

The primary license for the boilerplate is MIT, see [`LICENSE`](https://github.com/defi-wonderland/opUSDC/blob/main/LICENSE)
