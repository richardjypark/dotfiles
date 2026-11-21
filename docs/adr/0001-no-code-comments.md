# No code comments in repo-authored scripts

Comments in our shell, Python, and TypeScript drifted from the code, repeated it, or excused a workaround so that the workaround spread. We decided that code carries no comments: names, tests, and error messages carry the meaning, decisions go in `docs/adr/`, and known defects go in issues.

`scripts/comment-ratchet.py` counts comment lines per file, and `tests/comment-baseline.tsv` holds the allowed count. The count can only go down: `--check` (in `tests/all`) fails when a file has more comment lines than its baseline, and also when it has fewer, so that each reduction is locked in with `--update`. `--update` refuses an increase.

## Scope

Counted: repo-authored shell, Python, and TypeScript (see `INCLUDE` and `EXCLUDE` in the script). Not counted: config files (zsh, tmux, Neovim, Hyprland), `*.example` templates, pinned third-party code (`private_dot_agents/private_skills/`, the Pi `subagent` extension), and Python docstrings.

Exempt because they are not comments: shebangs; tool pragmas (`# shellcheck`, `# noqa`, `// @ts-`); comment lines with `{{ }}` in chezmoi templates, which are hash triggers that make `run_onchange_` scripts rerun; and heredoc bodies, which are file content that a script writes.

## Consequences

- Changing the text of a `run_onchange_` script, or of a helper whose hash it includes, makes chezmoi rerun it on the next apply. Comment-only clean-ups are not free.
- Some decision records stay as comments until a later pass moves them; the baseline counts them. Use the `delete-comment` skill for the next pass.
