| Properties                                                                                                  | Type       |
| ----------------------------------------------------------------------------------------------------------- | ---------- |
| Both messenger's state of if they can send messages should match                                            | High level |
| New messages should not be sent if the state is not active                                                  | High level |
| All in flight transactions should successfully settle after a migration to native usdc                      | High level |
| Bridged USDC Proxy should only be upgradeable through the L2 Adapter                                        | High level |
| Incoming successful messages should only come from the linked adapter's                                     | High level |
| Any chain should be able to have as many protocols deployed without the factory blocking deployments        | High level |
| All addresses precomputed in the factory match the deployed addresses                                       | High level |
| Deprecated state should be irreversible                                                                     | High level |
| User who bridges tokens should receive them on the destination chain                                        | High level |
| Protocols deployed on one L2 should never have a matching address with a protocol on a different L2         | High level |
| Assuming the adapter is the only minter the amount locked in L1 should always equal the amount minted on L2 | High level |
| USDC proxy admin and token ownership rights can only be transferred during the migration to native flow     | High level |
| Different L2 deployed contracts addresses can never match on different L2s                                  | High level |
| Precalculated addresses on the L1 Factory should always match the deployed addresses on L2s                 | High level |
