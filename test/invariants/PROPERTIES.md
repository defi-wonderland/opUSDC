| Properties                                                                                                   | Type       |
|--------------------------------------------------------------------------------------------------------------|------------|
| Both messenger's state of if they can send messages should match                                             | High level |
| New messages should not be sent if the state is not active                                                   | High level |
| All in flight transactions should successfully settle after a migration to native usdc                       | High level |
| Bridged USDC Proxy should only be upgradeable through the L2 Adapter                                         | High level |
| Incoming  successful messages should only come from the linked adapter's                                     | High level |
| Any chain should be able to have as many protocols deployed without the factory blocking deployments         | High level |
| All addresses precomputed in the factory match the deployed addresses                                        | High level |
| Deprecated state should be irreversible                                                                      | High level |
| User who bridges tokens should receive them on the destination chain                                         | High level |
| Protocols deployed on one L2 should never have a matching address with a protocol on a different L2          | High level |
| Assuming the adapter is the only minter the amount locked in L1 should always equal the amount minted on L2  | High level |
| Adapter can´t upgrade, transfer admin or ownership on bridgedUSDC contract by sendUsdcOwnableFunction func.  | High level |