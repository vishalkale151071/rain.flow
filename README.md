# rain.flow

Docs at https://rainprotocol.github.io/rain.flow

# Current version

## V3

V3 compatible contracts are still found in the monorepo at

https://github.com/rainprotocol/rain-protocol

The contracts in this repo are targetting V4 (see below).

# Unstable versions

## V4

The main changes in V4 replace `previewFlow` with `stackToFlow` which is a more
generalised version of the same basic idea. By allowing any stack to be passed
to the flow contract, the reader can simulate flows based on differen callers,
state, time, etc.

V4 also targets a newer interpreter interface than V3, notably the native parsing
functionality that works off a single `bytes` for the Rain bytecode rather than
the `bytes[]` that older interpreters expected.

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