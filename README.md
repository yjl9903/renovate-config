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

The recommended [Renovate workflow](.github/workflows/renovate.yml) keeps
`deps` synchronized with `main` and maintains a single rollup pull request:

1. A push to `main` rebases `deps` onto it, resolves conflicts in favor of
   `main`, refreshes `pnpm-lock.yaml`, and pushes with `--force-with-lease`.
2. A push to `deps` opens a `deps` to `main` pull request if one is not already
   open.
3. After that pull request is merged, `deps` is reset to `main` unless Renovate
   has already added newer commits.

This workflow is intended for pnpm repositories with `main` as the default
branch. Before enabling it:

1. Create the `deps` branch from `main` and push it.
2. Copy [the workflow](.github/workflows/renovate.yml) into the consuming
   repository at `.github/workflows/renovate.yml`.
3. Allow GitHub Actions to write repository contents and create pull requests.
4. Ensure the `deps` branch rules permit the workflow to push with
   `--force-with-lease`.

## License

MIT License © 2023 [XLor](https://github.com/yjl9903)
