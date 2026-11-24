# XLor's Renovate Config

## Usage

Add this preset to your `renovate.json`.

```json
{
  "extends": ["github>yjl9903/renovate-config"]
}
```

## Renovate dependency update workflow

The default preset uses two Renovate base branches.

- GitHub Actions updates target `main`, so workflow dependencies stay current.
- All other dependency updates target `deps`.

The `renovate-deps` action keeps `deps` synchronized with `main` and combines
dependency updates in a single pull request. [Action definition](.github/actions/renovate-deps/action.yml)

1. A push to `main` creates `deps` from `main` when it is missing. Otherwise,
   it rebases `deps` onto `main`, resolves conflicts in favor of `main`,
   refreshes `pnpm-lock.yaml`, and pushes with `--force-with-lease`.
2. A push to `deps` opens a `deps` to `main` pull request if one is not already
   open.
3. After that pull request is merged, `deps` is reset to `main` unless Renovate
   has already added newer commits.

Add this workflow at `.github/workflows/renovate.yml`. The action uses the Node.js
and pnpm versions from your repository's `mise.toml` after rebasing `deps`.

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
  renovate-deps:
    runs-on: ubuntu-latest
    steps:
      - uses: yjl9903/renovate-config/.github/actions/renovate-deps@main
```

Allow GitHub Actions to create pull requests in the repository settings and
ensure the `deps` branch rules permit the workflow's force push with lease.
The first push to `main` initializes `deps` automatically.

## License

MIT License © 2023 [XLor](https://github.com/yjl9903)
