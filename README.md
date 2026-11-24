# XLor's Renovate Config

## Usage

Add this preset to your `renovate.json`.

```json
{
  "extends": ["github>yjl9903/renovate-config"]
}
```

## Dependency rollup workflow

The default preset uses two Renovate base branches:

- GitHub Actions updates target `main`, so the rollup workflow itself stays current.
- All other dependency updates target `deps`.

The dependency rollup action keeps `deps` synchronized with `main` and maintains
a single rollup pull request. [Action definition](.github/actions/dependency-rollup/action.yml)

1. A push to `main` creates `deps` from `main` when it is missing. Otherwise,
   it rebases `deps` onto `main`, resolves conflicts in favor of `main`,
   refreshes `pnpm-lock.yaml`, and pushes with `--force-with-lease`.
2. A push to `deps` opens a `deps` to `main` pull request if one is not already
   open.
3. After that pull request is merged, `deps` is reset to `main` unless Renovate
   has already added newer commits.

For a pnpm repository, add this workflow at `.github/workflows/renovate.yml`.

```yaml
name: Renovate

on:
  push:
    branches: [main, deps]
  pull_request:
    branches: [main]
    types: [closed]

permissions:
  contents: write
  pull-requests: write

concurrency:
  group: renovate
  queue: max

jobs:
  dependency-rollup:
    runs-on: ubuntu-latest
    steps:
      - uses: yjl9903/renovate-config/.github/actions/dependency-rollup@main
```

Allow GitHub Actions to create pull requests in the repository settings and
ensure the `deps` branch rules permit the workflow's force push with lease.
The first push to `main` initializes `deps` automatically.

The action reads the pnpm version from the root `package.json` and uses Node.js
`24.18.0` by default. Set `node-version` to override it, or set
`refresh-lockfile: 'false'` to use the branch and PR automation without pnpm.
If you override `base-branch` or `deps-branch`, use the same branch names in the
workflow triggers and your Renovate configuration.

## License

MIT License © 2023 [XLor](https://github.com/yjl9903)
