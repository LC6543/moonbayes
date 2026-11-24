# moonbayes

`moonbayes` is a MoonBit-native library for discrete Bayesian networks. It
focuses on deterministic, bounded, I/O-free inference primitives that work on
the native, JavaScript and WebAssembly backends.

The first increment implements dense factor tables. A factor is an ordered
scope plus a table of finite non-negative weights. The implementation provides:

- validated finite discrete variables
- row-major assignment and index conversion
- table validation with explicit errors
- factor multiplication over shared scopes
- marginalization by summing out variables
- evidence restriction with structured validation
- Bayesian network construction with DAG and conditional-table checks
- exact variable elimination with deterministic minimum-fill ordering
- ancestor, descendant and d-separation structure queries
- evidence likelihood with scaled log-probability accumulation
- deterministic likelihood-weighting posterior sampling
- deterministic ancestral sampling of complete joint assignments
- MAP and MPE assignments from exact posterior maximization
- versioned JSON model import and export with validation
- complete-data CPT fitting with configurable smoothing
- normalization and total-mass checks
- a hard table-size limit to reject malformed models early

Model editing and richer diagnostics are planned next.

## Development

This repository is not published yet. From a development checkout:

```sh
moon check --target all --deny-warn
moon build --target all --deny-warn
moon test --target all --deny-warn
moon run examples/basic
```

## Command Line

Build and run the native command-line tool with:

```sh
moon run cmd/moonbayes --target wasm-gc -- --help
moon run cmd/moonbayes --target wasm-gc -- validate examples/rain-umbrella.json
moon run cmd/moonbayes --target wasm-gc -- query examples/rain-umbrella.json --target rain --evidence umbrella=1
moon run cmd/moonbayes --target wasm-gc -- likelihood examples/rain-umbrella.json --evidence umbrella=1
moon run cmd/moonbayes --target wasm-gc -- map examples/rain-umbrella.json --target rain --evidence umbrella=1
moon run cmd/moonbayes --target wasm-gc -- plan examples/rain-umbrella.json --target rain --evidence umbrella=1
```

## Example

```moonbit
let rain = @moonbayes.Variable::new("rain", 2).unwrap()
let umbrella = @moonbayes.Variable::new("umbrella", 2).unwrap()
let prior = @moonbayes.Factor::new([rain], [0.8, 0.2]).unwrap()
let likelihood = @moonbayes.Factor::new(
  [rain, umbrella],
  [0.9, 0.1, 0.2, 0.8],
).unwrap()
let umbrella_cpt = @moonbayes.Factor::new(
  [umbrella, rain],
  [0.9, 0.2, 0.1, 0.8],
).unwrap()
let joint = prior.multiply(likelihood).unwrap()
let p_umbrella = joint.marginalize(["umbrella"]).unwrap()
let observed = joint.restrict([("rain", 0)]).unwrap()
let posterior = observed.normalize().unwrap()
let rain_node = @moonbayes.NetworkNode::new(rain, [], prior).unwrap()
let umbrella_node = @moonbayes.NetworkNode::new(
  umbrella,
  ["rain"],
  umbrella_cpt,
).unwrap()
let network = @moonbayes.BayesianNetwork::new(
  [rain_node, umbrella_node],
).unwrap()
let inferred_rain = network.query(["rain"], [("umbrella", 1)]).unwrap()
let d_separated = network.is_d_separated(["rain"], ["umbrella"], []).unwrap()
let likelihood = network.evidence_likelihood([("umbrella", 1)]).unwrap()
let sampling_config = @moonbayes.SamplingConfig::new(10000, 42UL).unwrap()
let sampled = network.sample_posterior(
  ["rain"],
  [("umbrella", 1)],
  sampling_config,
).unwrap()
let map_rain = network.map(["rain"], [("umbrella", 1)]).unwrap()
let encoded = network.to_json_string()
let restored = @moonbayes.BayesianNetwork::from_json_string(encoded).unwrap()
let fitted = network.fit_complete_data(
  [
    [("rain", 0), ("umbrella", 0)],
    [("rain", 1), ("umbrella", 1)],
  ],
  1.0,
).unwrap()
```

The last variable changes fastest. For a factor over `rain(2), umbrella(2)`,
index `0` is `(0, 0)`, index `1` is `(0, 1)`, index `2` is `(1, 0)`, and index
`3` is `(1, 1)`.

See `PROPOSAL.md` for the one-page project proposal and
`docs/overlap-audit.md` for the Mooncakes overlap review.

## License

MIT. See `LICENSE`.
