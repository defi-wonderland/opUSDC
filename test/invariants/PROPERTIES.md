| Properties                                                                                                  | Type                | Id  | Fuzz | Symb |
| ----------------------------------------------------------------------------------------------------------- | ------------------- | --- | ---- | ---- |
| New messages should not be sent if the state is not active                                                  | Unit test           | 1   | [X]  | [ ]  |
| User who bridges tokens should receive them on the destination chain                                        | High level          | 2   | [X]  | [ ]  |
| Assuming the adapter is the only minter the amount locked in L1 should always equal the amount minted on L2 | High level          | 3   | [X]  | [ ]  |
| Both messenger's state or if they can send messages should match                                            | Valid state         | 4   | [X]  | [ ]  |
| user nonce should be monotonically increasing                                                               | Variable transition | 5   | [X]  | [ ]  |
| burn locked only if deprecated                                                                              | Unit test           | 6   | [X]  | [ ]  |
| paused only via stop messaging                                                                              | State transition    | 7   | [X]  | [ ]  |
| resumed only via resume messaging                                                                           | State transition    | 8   | [X]  | [ ]  |
| set burn only if migrating state                                                                            | State transition    | 9   | [ ]  | [ ]  |
| Deprecated state should be irreversible                                                                     | State transition    | 10  | [ ]  | [ ]  |
| Upgrading state only via migrate to native, should be callable multiple times (msg fails)                   | State transition    | 11  | [ ]  | [ ]  |
| All in flight transactions should successfully settle after a migration to native usdc                      | High level          | 12  | [ ]  | [ ]  |
| Bridged USDC Proxy should only be upgradeable through the L2 Adapter                                        | High level          | 13  | [ ]  | [ ]  |
| Incoming successful messages should only come from the linked adapter's                                     | High level          | 14  | [ ]  | [ ]  |
| Any chain should be able to have as many protocols deployed without the factory blocking deployments        | High level          | 15  | [ ]  | [ ]  |
| Protocols deployed on one L2 should never have a matching address with a protocol on a different L2         | High level          | 16  | [ ]  | [ ]  |
| USDC proxy admin and token ownership rights can only be transferred during the migration to native flow     | High level          | 17  | [ ]  | [ ]  |
| Status should either be active, paused, upgrading or deprecated                                             | Valid state         | 18  | [ ]  | [ ]  |
| All addresses precomputed in the factory match the deployed addresses / L1 nonce == L2 factory nonce        | Variable transition |     | depr | [ ]  |