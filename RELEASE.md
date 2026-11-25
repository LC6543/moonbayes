# Release Checklist

## Repository

- [x] New standalone repository and module namespace `LC6543/moonbayes`
- [x] Root MIT license
- [x] README with installation, library examples, and CLI usage
- [x] One-page competition proposal
- [x] Mooncakes overlap audit
- [x] GitHub Actions checks, build, tests, examples, CLI, formatting, packaging
- [x] At least 10 meaningful commits
- [ ] Push local `main` to the public GitHub repository

## Local verification

```sh
moon check --target all --deny-warn
moon test --target wasm --deny-warn
moon test --target wasm-gc --deny-warn
moon build --target js --deny-warn
moon run examples/acceptance
moon run cmd/moonbayes --target wasm-gc -- validate examples/rain-umbrella.json
moon fmt --check
moon package
```

## Mooncakes

- [ ] Confirm `moon whoami` uses the `LC6543` namespace
- [ ] Run `moon info` and review generated interfaces
- [ ] Run `moon publish`
- [ ] Verify the public Mooncakes documentation page
- [ ] Install the published package in a clean project

## Initial review

- [ ] Confirm the GitHub repository is public and `main` is the default branch
- [ ] Confirm the README and proposal links resolve
- [ ] Confirm CI passes on the pushed commit
- [ ] Submit the repository link with the proposal
