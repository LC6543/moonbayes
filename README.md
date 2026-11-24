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
- normalization and total-mass checks
- a hard table-size limit to reject malformed models early

Sampling and approximate inference are planned next and intentionally not
stubbed.

## Development

This repository is not published yet. From a development checkout:

```sh
moon check --target all --deny-warn
moon build --target all --deny-warn
moon test --target all --deny-warn
moon run examples/basic
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
```

The last variable changes fastest. For a factor over `rain(2), umbrella(2)`,
index `0` is `(0, 0)`, index `1` is `(0, 1)`, index `2` is `(1, 0)`, and index
`3` is `(1, 1)`.

See `PROPOSAL.md` for the one-page project proposal and
`docs/overlap-audit.md` for the Mooncakes overlap review.

## License

MIT. See `LICENSE`.
