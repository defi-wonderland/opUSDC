# Bridged USDC Standard for the OP Stack

USDC is one of the most bridged assets across the crypto ecosystem, and USDC is often bridged to new chains prior to any action from Circle. This can create a challenge when bridged USDC achieves substantial marketshare, but native USDC (issued by Circle) is preferred by the ecosystem, leading to fragmentation between multiple representations of USDC. Circle introduced the [Bridged USDC Standard](https://www.circle.com/en/bridged-usdc) to ensure that chains can easily deploy a form of USDC that is capable of being upgraded in-place by Circle to native USDC, if and when appropriate, and prevent the fragmentation problem.

Bridged USDC Standard for the OP Stack allows for an efficient and modular solution for expanding the Bridged USDC Standard across the Superchain ecosystem.

Chain operators can use the Bridged USDC Standard for the OP Stack to get bridged USDC on their OP Stack chain while also providing the optionality for Circle to seamlessly upgrade bridged USDC to native USDC and retain existing supply, holders, and app integrations.

## Contracts

> :exclamation: `L1OpUSDCFactory.sol` has been deployed to the following addresses:

- Mainnet: `0x7dB8637A5fd20BbDab1176BdF49C943A96F2E9c6`
- Sepolia: `0x82c6c4940cE0066B9F8b500aBF8535810524890c`

> :exclamation: `L1OpUSDCBridgeAdapter.sol` has been deployed to the following addresses:

- Sepolia: `0x0429b5441c85EF7932B694f1998B778D89375b12`

> :exclamation: `L2OpUSDCBridgeAdapter.sol` has been deployed to the following addresses:

- Optimism Sepolia: `0xCe7bb486F2b17735a2ee7566Fe03cA77b1a1aa9d`

> :exclamation: `Bridged USDC` contract has been deployed to the following addresses:

- Optimism Sepolia: `0x7a30534619d60e4A610833F985bdF7892fD9bcD5`

_`L1OpUSDCFactory.sol`_ - Factory contract to deploy and setup the `L1OpUSDCBridgeAdapter` contract on L1. Precalculates the addresses of the L2 deployments and triggers their deployment, by sending a transaction to L2.

_`L2OpUSDCDeploy.sol`_ - One time use deployer contract deployed from the L1 factory through a cross-chain deployment. Used as a utility contract for deploying the L2 USDC Proxy, and `L2OpUSDCBridgeAdapter` contract, all at once in its constructor.

_`L1OpUSDCBridgeAdapter`_ - Contract that allows for the transfer of USDC from Ethereum Mainnet to a specific OP Stack chain. Locks USDC on Ethereum Mainnet and sends a message to the other chain to mint the equivalent amount of USDC. Receives messages from the other chain and unlocks USDC on the Ethereum Mainnet. Controls the message flow between layers. Supports the requirements for the Bridged USDC to be migrated to Native USDC should the chain operator and Circle want to.

_`L2OpUSDCBridgeAdapter`_ - Contract that allows for the transfer of USDC from the specific OP Stack chain to Ethereum Mainnet. Burns USDC on the L2 and sends a message to Ethereum Mainnet to unlock the equivalent amount of USDC. Receives messages from Ethereum Mainnet and mints USDC. Allows chain operator to execute arbitrary functions on the Bridged USDC contract as if they were the owner of the contract.

## L1 → L2 Deployment

![image](https://github.com/user-attachments/assets/cc88f1df-f699-490d-aaa9-e4d2e02f28a9)

## L1 → L2 USDC Canonical Bridging

![image](https://github.com/defi-wonderland/opUSDC/assets/165055168/eaf55522-e768-463f-830b-b9305cec1e79)

For a user to make a deposit, the process is the following:

### Deposits

1. Users approve the `L1OpUSDCBridgeAdapter` to spend USDC.
2. Users proceed to deposit USDC by calling the contract.
3. The `L1OpUSDCBridgeAdapter` sends the message to the appointed CrossDomainMessenger.
4. The message is digested and included by the sequencer.
5. The `L1OpUSDCBridgeAdapter` mints the specified amount of `bridgedUSDC` to the user.

Similarly, for withdrawals:

### Withdrawals

1. Users send `bridgedUSDC` to the `L2OpUSDCBridgeAdapter`.
2. The `L2OpUSDCBridgeAdapter` burns the token.
3. The `L2OpUSDCBridgeAdapter` sends the message to the appointed CrossDomainMessenger.
4. The message is eventually included and proven on L1.
5. Wait for the challenge period (at least 7 days).
6. The receiving user (or relayers) withdraws the message after the challenge period, which is then forwarded to the `L1OpUSDCBridgeAdapter` that releases the specified amount of USDC to the user.

> **You can test the bridging flows using [Brid.gg in Sepolia](https://testnet.brid.gg/op-sepolia?amount=1&originChainId=11155111&token=USDC).**

## Migrating from Bridged USDC to Native USDC

![image](https://github.com/user-attachments/assets/291aae4c-e9fb-43a5-a11d-71bb3fc78311)

### Summary

Bridged USDC representation involves locking liquidity in the home chain and minting tokens on the destination chain. Migrating to native means transferring ownership of the bridged USDC to Circle and burning the locked funds on the home chain to consolidate liquidity across chains, making the bridged USDC canonical. ⚠️ This process is irreversible and will deprecate the adapters ⚠️.

### Step by step

1. Call `migrateToNative()` on L1
   1. Params
      1. `_roleCaller` The address that will be allowed to transfer the USDC roles on the destination chain.
      2. `_burnCaller` The address that will be allowed to call this contract to burn the USDC tokens
      3. `_minGasLimitReceiveOnL2` Minimum gas limit that the message for the`receiveMigrateToNative` call can be executed with on L2
      4. `_minGasLimitSetBurnAmount` Minimum gas limit that the message can be executed with to set the burn amount (This param is set on L2, and it represents the `minGasLimit` for when the withdrawal is finalized on L1)
   2. Effects
      1. Sets the `burnCaller` variable
      2. Changes the `messengerStatus` variable locking this function to avoid calling this process twice and locking `sendMessage`, `stopMessaging` and `resumeMessaging`
         Enables `setBurnAmount` that is only callable by the Linked Adapter.
      3. Sends message to call `receiveMigrateToNative` on destination chain.
   3. ⚠️ Note: Once this step is executed the bridges can’t be unpaused.
2. Call `receiveMigrateToNative` on L2 (Automatically relayed)

   1. Params
      1. `_roleCaller` The address that will be allowed to transfer the USDC roles on the destination chain.
      2. `_setBurnAmountMinGasLimit` Minimum gas limit that the setBurnAmount message can be executed on L1
   2. Effects
      1. Changes the `messengerStatus` variable locking `receiveStopMessaging`, `receiveResumeMessaging`, and `sendMessage`. Modifying `receiveMessage` behavior to return pending messages to L1 that could arrive after the migration. Also, modifies `withdrawLockedFunds` behavior to send the locked funds to the spender through a message to L1.
      2. Removes L2 Adapter as minter form USDC contract.
      3. Calculates the amount of USDC that is going to be burned on origin.
      4. Sends message to call `setBurnAmount` on origin chain.
   3. Note: This function is not blocked to be triggered again from L1 if a withdrawal for `setBurnAmount` was not yet finalized.

   ***

   After this point L1 (burn locked USDC) and L2 sequences (transfer bridged USDC roles) can be called in any order.

   ***

- L2 Sequence
  1. Call `transferUSDCRoles`
     1. Params
        1. `_owner` The address to transfer ownership to
     2. Effects
        1. Transfers the ownership of the Bridged USDC contract to the `_owner`
        2. Transfer the admin rights of the Bridged USDC proxy to the `msg.sender` (a.k.a. `roleCaller`)
- L1 Sequence (MUST wait at least 7 days to execute this sequence).
  1. Call `setBurnAmount`
     1. Params
        1. `_amount` The amount of USDC tokens that will be burned
     2. Effects
        1. Sets `burnAmount` variable that will be later used by `burnLockedUSDC`
        2. Changes the `messengerStatus` to `Deprecated` disabling all the function related to migration and sending messages.
     3. ⚠️ Note: After this point the `burnCaller` and the `roleCaller` are not longer updatable
  2. Call `burnLockedUSDC`
     1. Effects
        1. Burns the USDC locked in the adapter based on the `burnAmount` variable or the contract balance.
        2. Reset `burnAmount` and `burnCaller` variables, to avoid calling the function more than once.
        3. `receiveWithdrawLockedFundsPostMigration` is enabled, this function handles the messages that were in-flight during the migration and were sent back from L2 by transferring the locked USDC to the user.

## Security

The referenced implementation for the OP Stack has undergone audits from [Spearbit](https://spearbit.com/) and is recommended for production use. The audit report is available [here](./audits/spearbit.pdf).

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

> :exclamation: `BRIDGED_USDC_IMPLEMENTATION` needs to be deployed ahead of time onto the target L2 chain.

In order to deploy the opUSDC protocol for your OP Stack chain, you will need to fill out these variables in the `.env` file:

```python
# The factory contract address on L1
L1_FACTORY=0x7dB8637A5fd20BbDab1176BdF49C943A96F2E9c6
# The bridged USDC implementation address on L2
BRIDGED_USDC_IMPLEMENTATION=
# The address of your CrossDomainMessenger on L1
L1_MESSENGER=
# The name of your chain
CHAIN_NAME=
# The private key that will sign the transactions on L1
PRIVATE_KEY=
# Ethereum RPC URL for the Parent Chain (e.g. Ethereum Mainnet or Ethereum Sepolia)
ETHEREUM_RPC=
```

After all these variables are set, navigate to the `script/mainnet/Deploy.s.sol` file and edit the following lines with your desired configuration, we add a sanity check that will revert if you forget to change this value:

```solidity
    // NOTE: We have these hardcoded to default values, if used in product you will need to change them

    bytes[] memory _usdcInitTxs = new bytes[](3);
    string memory _name = string.concat('Bridged USDC', ' ', '(', chainName, ')');

    _usdcInitTxs[0] = abi.encodeCall(IUSDC.initializeV2, (_name));
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

In addittion, the L1OpUSDCFactory deployment command is:

```bash
yarn deploy:mainnet:factory
```

And when you are ready to deploy to mainnet, run:

```bash
yarn deploy:mainnet:factory:broadcast
```

Alternatively, you can run the deployment scripts over your desired testent by replacing mainnet with testnet in the commands above.

### Tips For Verifying

- Remember to set the EVM version to `paris` when verifying the contracts.
- Remember to add the `--via-ir` version if you compiled the contracts with the optimized flag and you're verifying them through the CLI.
- If you are verifying manually through a block explorer UI, you can choose a single Soldiity file option and use `forge flatten <contract_name> > <flattened_contract_name>` to get the flattened contract and avoid having to upload multiple Solidity files.
- If you're facing issues with the `L1OpUSDCFactory` verification, you can resolve them by adding the `CrossChainDeployments` library address to the `L1OpUSDCFactory.json` file as shown below:

  ```json
      "libraries": {
        "src/libraries/CrossChainDeployments.sol": {
            "CrossChainDeployments":"<CROSS_CHAIN_DEPLOYMENTS_ADDRESS>"
        }
  ```

## Migrating to Native USDC

> ⚠️ Migrating to native USDC is a manual process that requires communication with Circle, this section assumes both parties are ready to migrate to native USDC. Please review [Circle’s documentation](https://www.circle.com/blog/bridged-usdc-standard) to learn about the process around Circle obtaining ownership of the Bridged USDC Standard token contract.

In order to migrate to native USDC, you will need to fill out these variables in the `.env` file:

```python
# The address of the L1 opUSDC bridge adapter
L1_ADAPTER=
# The private key of the transaction signer, should be the owner of the L1 Adapter
L1_ADAPTER_OWNER_PK=
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

### What will Circle need at migration?

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
