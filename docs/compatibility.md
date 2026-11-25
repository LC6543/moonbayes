# Compatibility

## Model format

- Format identifier: `moonbayes`
- Format version: `1`
- Variable domains are finite and positive integers.
- Conditional probability tables use child-first, last-variable-fastest order.

## Runtime support

The core model and inference packages contain no filesystem, network, or
platform FFI calls.

- `wasm`: checked and unit tested.
- `wasm-gc`: checked, unit tested, and used for CLI execution.
- `js`: checked and built.
- `native`: checked; local runtime tests require an available MSVC toolchain.
- Linux CI runs `moon check`, build, tests, examples, and package validation.

The command-line package uses `moonbitlang/x/fs` and is verified with
`wasm-gc`. Native execution requires a standard MoonBit native toolchain.

## Numerical behavior

- Factor weights must be finite and non-negative.
- Conditional tables must sum to one for every parent assignment.
- Evidence likelihood accumulates scaling in log space.
- Posterior sampling aggregates weights with log-sum-exp.
- Impossible evidence returns linear probability zero and log probability
  negative infinity.

## Explicit boundaries

The current release supports finite discrete variables and exact inference over
acyclic networks. It does not implement continuous variables, MCMC, variational
inference, structure learning, continuous CPDs, model visualization, or native
file formats beyond the versioned JSON representation.
