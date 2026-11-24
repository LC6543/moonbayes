# Mooncakes overlap audit

Audit date: 2026-11-24

The selection was checked with `moon search` before implementation. Queries
included `bayes`, `bayesian`, `probabilistic graphical`, `factor graph`,
`variable elimination`, `junction tree`, `d-separation`, `bayesnet` and
`moonbayes`.

## Nearest packages

- `tyytyy68/moon-bayes-kit` implements composable Bayesian online updates. It
  does not expose a discrete network graph, dense factor tables, or variable
  elimination.
- `riantr/moonbit_dowhy` focuses on causal effect identification and
  estimation. It is not a general discrete Bayesian-network inference API.
- `code3055/moonmentor` is an application-specific Bayesian tutor rather than
  a reusable probabilistic graphical-model kernel.
- The existing public repositories owned by `LC6543`, `moonbit-h3` and
  `moonpdb`, are different projects and are not modified by this work.

No package with the proposed module name or with the same factor-table and
exact discrete inference scope was found. This project is a new module rather
than a fork, rename, or maintenance continuation.
