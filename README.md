# rain.flow

Docs at https://rainprotocol.github.io/rain.flow

# Deprecated versions

## V2

V2 was deprecated to remove native flows entirely from the V3+ interface.

This is because flow implementations are likely to want to implement `Multicall`
like functionality, such as that provided by Open Zeppelin.

`Multicall` based on delegate call preserves the `msg.sender` which is great for
allowing EOA wallets like Metamask to flow under their own identity, but is a
critical security issue when reading `msg.value` (e.g. to allow native flows).

https://samczsun.com/two-rights-might-make-a-wrong/

## V1

V1 was deprecated because the `SignedContext` struct that it relies on was
deprecated upstream. `SignedContext` was replaced with `SignedContextV1` which
was a minor change, reordering fields only for more efficient processing.