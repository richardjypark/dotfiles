# Validation and CI Patterns

Use these patterns when a chezmoi repository needs one dependable validation contract across macOS, Linux, local development, and CI.

## One validation entry point

- Keep one executable aggregate command, such as `./tests/all`.
- Run focused tests during the edit loop and the aggregate command before task completion.
- Continue after individual suite failures so the final output shows the full failure set.
- Report passed, failed, and skipped suites separately. A skip is not a pass.
- Let local mode skip dependency-heavy suites when dependencies are absent.
- Give CI a required mode, such as `REQUIRE_MANAGED_NPM_TESTS=1`, where missing dependencies fail.

## Shell portability

- Validate tracked shell files dynamically instead of maintaining a long static file list.
- Render chezmoi shell templates before syntax checking them.
- On macOS, canonicalize fixture directories before exact path comparisons:

  ```bash
  root="$(mktemp -d)"
  root="$(cd "$root" && pwd -P)"
  ```

  This prevents `/var/...` and `/private/var/...` from comparing as different paths.
- Apple Bash 3.2 treats expansion of an empty array under `set -u` differently from current Bash. Before passing an argument array, branch on `${#args[@]}` and invoke the no-argument form explicitly.
- Identify sourced Zsh fragments separately from Bash scripts. A `.sh` suffix does not prove Bash syntax.

## Managed dependency projects

- Before running a local install inside a chezmoi source tree, add generated dependency paths to both `.gitignore` and `.chezmoiignore`.
  - `.gitignore` prevents Git or Jujutsu snapshots.
  - `.chezmoiignore` prevents chezmoi from scanning or rendering dependency trees.
- Install from committed lockfiles with lifecycle scripts disabled unless the project explicitly requires them.
- Explicitly include development dependencies for type checks and builds; host variables such as `NODE_ENV=production` can otherwise omit them.
- Build into a temporary directory. Do not overwrite or delete an existing source-tree build directory during validation.
- After strict local verification, remove generated dependencies and rerun the default validation mode to verify expected skip behavior.

## CI convergence

- Make CI call the same aggregate command used locally.
- Use a full Linux job for dependency-heavy suites and a lightweight macOS job for portable core behavior.
- Install the repository-pinned chezmoi version and verify its checksum before template validation.
- Keep CI bootstrap parsers compatible with the oldest interpreter expected on supported hosts. Avoid using a new standard-library module only to read a small pinned-data section when a simple bounded parser is sufficient.

## Verification sequence

1. Run focused failing tests and record the baseline.
2. Repair portability defects and rerun focused tests.
3. Run the default aggregate mode with dependencies absent; confirm explicit skips.
4. Install all managed dependencies from lockfiles.
5. Run required mode; require zero failures and zero skips.
6. Remove generated dependencies.
7. Run the default mode again.
8. Run workflow syntax checks and `git diff --check`.
9. Confirm repo-only tests and generated dependencies are not chezmoi-managed.
10. Run `chezmoi diff`; do not apply unrelated pre-existing target drift.

## Common pitfalls

- A package manifest can reference a missing test file even when its binary smoke test passes. Run the package test command in strict CI mode.
- An aggregate runner without `set -e` inside a multi-command suite can hide an early test failure when the last command succeeds.
- Running Jujutsu status before dependency paths are ignored can snapshot large generated trees. Add ignore rules first.
- Do not claim hosted CI passed when only the workflow YAML and local equivalent were validated. State that a push is still required for the hosted matrix.
