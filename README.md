# Bridged USDC Standard for the OP Stack

USDC is one of the most bridged assets across the crypto ecosystem, and USDC is often bridged to new chains prior to any action from Circle. This can create a challenge when Bridged USDC achieves substantial marketshare, but Native USDC is preferred by the ecosystem, leading to fragmentation between multiple representations of USDC. Circle introduced the [Bridged USDC Standard](https://www.circle.com/blog/bridged-usdc-standard) to ensure that chains can easily deploy a form of USDC that is capable of being upgraded in-place by Circle to Native USDC, if and when appropriate, and prevent the fragmentation problem.

Bridged USDC Standard for the OP Stack allows for an efficient and modular solution for expanding the Bridged USDC Standard across the Superchain ecosystem. Utilizing the cross chain messaging of the canonical OP Stack bridge the adapter allows for easy access to Bridged USDC liquidity across OP Stack chains.

Chain operators can use the Bridged USDC Standard for the OP Stack to get Bridged USDC on their OP Stack chain while also providing the optionality for Circle to seamlessly upgrade Bridged USDC to Native USDC and retain existing supply, holders, and app integrations. 


## Contracts

_`L1OpUSDCFactory.sol`_ - Factory contract to deploy and setup the `L1OpUSDCBridgeAdapter` contract on L1. Precalculates the addresses of the L2 deployments and triggers their deployment, by sending a transaction to L2.

_`L2OpUSDCDeploy.sol`_ - One time use deployer contract deployed from the L1 factory through a cross-chain deployment. Used as a utility contract for deploying the L2 USDC Proxy, and `L2OpUSDCBridgeAdapter` contract, all at once in its constructor.

_`L1OpUSDCBridgeAdapter`_ - Contract that allows for the transfer of USDC from Ethereum Mainnet to a specific OP-chain. Locks USDC on Ethereum Mainnet and sends a message to the other chain to mint the equivalent amount of USDC. Receives messages from the other chain and unlocks USDC on the Ethereum Mainnet. Controls the message flow between layers. Supports the requirements for the Bridged USDC to be migrated to Native USDC should the chain operator and Circle want to.

_`L2OpUSDCBridgeAdapter`_ - Contract that allows for the transfer of USDC from the specific OP-chain to Ethereum Mainnet. Burns USDC on the L2 and sends a message to Ethereum Mainnet to unlock the equivalent amount of USDC. Receives messages from Ethereum Mainnet and mints USDC. Allows chain operator to execute arbitrary functions on the Bridged USDC contract as if they were the owner of the contract.

## L1 → L2 Deployment

![image](https://github.com/user-attachments/assets/cc88f1df-f699-490d-aaa9-e4d2e02f28a9)

## L1 → L2 USDC Canonical Bridging

![image](https://github.com/defi-wonderland/opUSDC/assets/165055168/eaf55522-e768-463f-830b-b9305cec1e79)

## Migrating from Bridged USDC to Native USDC

![image](https://github.com/user-attachments/assets/291aae4c-e9fb-43a5-a11d-71bb3fc78311)


## Security
Bridged USDC Standard for the OP Stack has undergone audits from [Spearbit](https://spearbit.com/) and is recommended for production use. The audit report is available [here](./audits/spearbit.pdf).

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

### What will circle need at migration?

#### Circle will need the metadata from the original deployment of the USDC implementation that was used
  
To do this you will need to go back to the `stablecoin-evm` github repo that the implementation was deployed from in order to extract the raw metadata from the compiled files. The compiled files are usually found in the `out/` or `artifacts/` folders. To extract the raw metadata you can run a command like this:

```bash
cat out/example.sol/example.json | jq -jr '.rawMetadata' > example.metadata.json
```

You will need to do this for both the token contract and any external libraries that get deployed with it, at the time of writing this these are `FiatTokenV2_2` and `SignatureChecker` but these are subject to change in the future.

## Licensing

The primary license for the boilerplate is MIT, see [`LICENSE`](https://github.com/defi-wonderland/opUSDC/blob/main/LICENSE)

## Bridged USDC Standard Factory Disclaimer
This software is provided “as is,” without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose, and noninfringement. In no event shall the authors or copyright holders be liable for any claim, damages, or other liability, whether in an action of contract, tort, or otherwise, arising from, out of, or in connection with the software or the use or other dealings in the software. 

Please review [Circle’s disclaimer](https://github.com/circlefin/stablecoin-evm/blob/master/doc/bridged_USDC_standard.md#for-more-information) for the limitations around Circle obtaining ownership of the Bridged USDC Standard token contract. 
