# Mixed-language monorepo example

Copy `mise.toml` to a project root that contains `apps/api` (Phoenix),
`apps/web` (pnpm), and `apps/jobs` (uv/Python). Change the runtime versions to
the versions that the project supports. Keep `uv.lock`, `pnpm-lock.yaml`, and
`mix.lock` in that project. The dotfiles repo does not own those lockfiles.

Install mise and uv on the workstation. From the project root, run:

```sh
mise trust
mise install
mise run setup
mise run test
```

Run `mise run dev:api` and `mise run dev:web` in separate terminals. Each task
uses the project root configuration. `mise run setup` can run its three tasks
in parallel. It does not set the order between them.

`uv` owns Python versions and environments. Run `uv python pin` in `apps/jobs`
if that application needs an exact Python version. Review task commands against
the real application before use.
