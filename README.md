<br />
<div align="center"><strong>This README is a WIP...</strong></div>
<br />

# opUSDC

opUSDC allows for an efficient and modular solution for expanding USDC across the optimism super chain ecosystem. Utilizing the cross chain messaging of the canonical bridge the adapter allows for easy access to USDC liquidity across all op chains. 

## Contracts

_L1OpUSDCBridgeAdapter_ - Contract that allows for the transfer of USDC from the L1 to the L2. Locks USDC on the L1 and sends a message to the L2 to mint the equivalent amount of USDC. Receives messages from the L2 and unlocks USDC on the L1. Controls the message flow between layers. Allows Circle to migrate from bridged USDC to native USDC on the L2.

_L2OpUSDCBridgeAdapter_ - Contract that allows for the transfer of USDC from the L2 to the L1. Burns USDC on the L2 and sends a message to the L1 to unlock the equivalent amount of USDC. Receives messages from the L1 and mints USDC on the L2. Allows contract owner to execute ownable functions on the L2 bridged USDC contract.

_L1OpUSDCFactory.sol_ - Factory contract to deploy and setup the `L1OpUSDCBridgeAdapter` and `UpgradeManager` contracts on L1, and precalculates the addresses of the L2 deployments to be done on the L2 factory.

_L2OpUSDCFactory.sol_ - Factory contract for deploying the L2 USDC implementation, proxy, and `L2OpUSDCBridgeAdapter` contract, all at once on the `deploy` function.

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

<br>

## Deploy & verify

### Setup

Configure the `.env` variables.

### Sepolia

```bash
yarn deploy:sepolia
```

### Mainnet

```bash
yarn deploy:mainnet
```

The deployments are stored in ./broadcast

See the [Foundry Book for available options](https://book.getfoundry.sh/reference/forge/forge-create.html).

## Export And Publish

Export TypeScript interfaces from Solidity contracts and interfaces providing compatibility with TypeChain. Publish the exported packages to NPM.

To enable this feature, make sure you've set the `NPM_TOKEN` on your org's secrets. Then set the job's conditional to `true`:

```yaml
jobs:
  export:
    name: Generate Interfaces And Contracts
    # Remove the following line if you wish to export your Solidity contracts and interfaces and publish them to NPM
    if: true
    ...
```

Also, remember to update the `package_name` param to your package name:

```yaml
- name: Export Solidity - ${{ matrix.export_type }}
  uses: defi-wonderland/solidity-exporter-action@1dbf5371c260add4a354e7a8d3467e5d3b9580b8
  with:
    # Update package_name with your package name
    package_name: "my-cool-project"
    ...


- name: Publish to NPM - ${{ matrix.export_type }}
  # Update `my-cool-project` with your package name
  run: cd export/my-cool-project-${{ matrix.export_type }} && npm publish --access public
  ...
```

You can take a look at our [solidity-exporter-action](https://github.com/defi-wonderland/solidity-exporter-action) repository for more information and usage examples.

## Licensing
The primary license for the boilerplate is MIT, see [`LICENSE`](https://github.com/defi-wonderland/solidity-foundry-boilerplate/blob/main/LICENSE)