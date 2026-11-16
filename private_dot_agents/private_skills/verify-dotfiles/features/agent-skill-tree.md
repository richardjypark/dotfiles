# Shared agent skill tree

The dotfiles install one shared skill tree at `~/.agents/skills` and point each agent client at it. Claude Code and Codex see the same skills. The root `AGENTS.md` is not rendered: it applies only inside the repo.

## Sub-features

- `skills-tree` renders every skill folder from `private_dot_agents/private_skills/` with its `SKILL.md`.
- `skills-links` makes `~/.claude/skills` and `~/.codex/skills` links to `~/.agents/skills`.
- `skills-helpers` keeps helper scripts executable after render.
- `skills-guides` renders no `~/AGENTS.md`, `~/CLAUDE.md`, or `~/.codex/AGENTS.md`.

## How to get to it (user POV)

- Start Claude Code, Codex, or Pi after apply and list the skills.
- Run a skill helper, such as `~/.agents/skills/verify-dotfiles/scripts/verify-dotfiles --help`.

## Driving it with verify-dotfiles

Preconditions:

- A ready workstation run from the source under test.

- **Tree.** Run `"$VD" shell "$RUN" skills-tree 'for d in ~/.agents/skills/*/; do test -f "$d/SKILL.md" || print -r -- "MISSING $d"; done; ls ~/.agents/skills | wc -l'`. No `MISSING` line, and the count equals the number of folders in `private_dot_agents/private_skills/` (plus `anatomy`, a pinned external, on the workstation role).
- **Links.** Run `"$VD" shell "$RUN" skills-links 'readlink ~/.claude/skills ~/.codex/skills'`. Both lines are `$RUN/home/.agents/skills`.
- **Helpers.** Run `"$VD" shell "$RUN" skills-helpers 'test -x ~/.agents/skills/verify-dotfiles/scripts/verify-dotfiles && ~/.agents/skills/verify-dotfiles/scripts/verify-dotfiles --help | head -1'`. Exit code `0` and the output starts with `Usage: verify-dotfiles`.
- **Guides.** Run `"$VD" shell "$RUN" skills-guides 'for f in ~/AGENTS.md ~/CLAUDE.md ~/.codex/AGENTS.md; do test -e "$f" && print -r -- "PRESENT $f"; done; print -r -- DONE'`. The output is only `DONE`.
- **Proof.** Keep the four outputs. For a new or renamed skill, also show its folder name in `skills-tree.out` or in `ls ~/.agents/skills`.

## Gotchas

- The links are absolute and point into the scratch home. Compare with `$RUN/home`, not with `~` of the real user.
- A skill that exists only in the source but is ignored for a role (such as `anatomy` on the server role) is correctly absent.
- `executable_` source names become executable targets. A helper without that prefix renders without the executable bit, and `test -x` fails.
