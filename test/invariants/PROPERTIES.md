| Properties                                                                                                  | Type                | Id  | Fuzz | Symb |
| ----------------------------------------------------------------------------------------------------------- | ------------------- | --- | ---- | ---- |
| New messages should not be sent if the state is not active                                                  | Unit test           | 1   | [X]  | [x]  |
| User who bridges tokens should receive them on the destination chain                                        | High level          | 2   | [X]  | [x]  |
| Assuming the adapter is the only minter the amount locked in L1 should always equal the amount minted on L2 | High level          | 3   | [X]  | [x]  |
| Both messenger's state or if they can send messages should match                                            | Valid state         | 4   | depr | depr |
| user nonce should be monotonically increasing                                                               | Variable transition | 5   | depr | depr |
| burn locked only if deprecated                                                                              | Unit test           | 6   | [X]  | [X]  |
| paused only via stop messaging                                                                              | State transition    | 7   | [X]  |      |
| resumed only via resume messaging                                                                           | State transition    | 8   | [X]  |      |
| set burn only if migrating state                                                                            | State transition    | 9   | [X]  |      |
| Deprecated state should be irreversible                                                                     | State transition    | 10  | [X]  |      |
| Upgrading state only via migrate to native, should be callable multiple times (msg fails)                   | State transition    | 11  | [X]  | [X]  |
| All in flight transactions should successfully settle after a migration to native usdc                      | High level          | 12  | [X]  | [X]  |
| Bridged USDC Proxy should only be upgradeable through the L2 Adapter                                        | High level          | 13  | [X]  | :(   |
| Incoming successful messages should only come from the linked adapter's                                     | High level          | 14  | [X]  | [X]  |
| Any chain should be able to have as many protocols deployed without the factory blocking deployments        | High level          | 15  | [X]  | :(   |
| Protocols deployed on one L2 should never have a matching address with a protocol on a different L2         | High level          | 16  | [X]  | :(   |
| USDC proxy admin and token ownership rights can only be transferred during the migration to native flow     | High level          | 17  | [X]  |      |
| Status should either be active, paused, upgrading or deprecated                                             | Valid state         | 18  | [X]  |      |
| All addresses precomputed in the factory match the deployed addresses / L1 nonce == L2 factory nonce        | Variable transition |     | depr | depr | 
| Adapters can't be initialized twice                                                                         | State transition    | 19  | [X]  |      |

[]      planed to implement and still to do
[x]     implemented and tested
:(      implemented but judged as incorrect (tool limitation, etc)
empty   not implemented and will not be (design, etc)
