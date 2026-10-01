#!/usr/bin/env python3
"""Publish one verified maintenance PR through the repository's guarded push."""

import argparse
import base64
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys

SPEC = importlib.util.spec_from_file_location("candidate", Path(__file__).with_name("check-maintenance-candidate.py"))
candidate = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(candidate)
PREFIX = "maintenance/routine-pins/"
REQUIRED_CHECKS = {"gitleaks", "validation (ubuntu-24.04)", "validation (macos-26)", "dependency-policy"}


def run(source, *args, data=None, missing=False):
    result = subprocess.run(args, cwd=source, input=data, capture_output=True, check=False)
    if missing and result.returncode and b"(HTTP 404)" in result.stderr:
        return None
    candidate.require(result.returncode == 0, f"{args[0]} {args[1]} failed; publication stopped")
    return result.stdout


def api(source, path, method="GET", body=None, missing=False):
    args = ["gh", "api", "--hostname", "github.com", path, "--method", method]
    if body is not None:
        args.extend(("--input", "-"))
    output = run(source, *args, data=json.dumps(body).encode() if body is not None else None, missing=missing)
    return json.loads(output) if output else None


def default_state(source, repository):
    candidate.require(candidate.REPOSITORY.fullmatch(repository), "invalid repository")
    metadata = api(source, f"repos/{repository}")
    branch = metadata["default_branch"]
    candidate.git(source, "check-ref-format", "refs/heads/" + branch)
    tip = api(source, f"repos/{repository}/git/ref/heads/{branch}")["object"]["sha"]
    candidate.require(candidate.COMMIT.fullmatch(tip), "invalid remote default revision")
    return branch, tip


def open_routine_prs(source, repository):
    found = []
    for page in range(1, 11):
        rows = api(source, f"repos/{repository}/pulls?state=open&per_page=100&page={page}")
        candidate.require(isinstance(rows, list), "invalid pull-request response")
        found.extend(row for row in rows if row["head"]["ref"].startswith(PREFIX))
        if len(rows) < 100:
            candidate.require(len(found) <= 1, "multiple routine pull requests need operator review")
            return found
    raise ValueError("open pull-request pagination limit reached")


def check_owner(pr, repository, branch, login, expected_head=None):
    candidate.require(re.fullmatch(r"[A-Za-z0-9-]+\[bot\]", login or ""), "configure the expected App bot login")
    candidate.require(pr["state"] == "open" and not pr["draft"] and pr["user"]["login"] == login,
                      "routine pull request is not an open PR owned by the configured App")
    candidate.require(pr["base"]["ref"] == branch and pr["base"]["repo"]["full_name"] == repository
                      and pr["head"]["repo"]["full_name"] == repository, "routine pull request source or base mismatch")
    candidate.require(re.fullmatch(re.escape(PREFIX) + r"[1-9]\d{0,19}", pr["head"]["ref"]), "unexpected routine branch")
    head = pr["head"]["sha"]
    candidate.require(candidate.COMMIT.fullmatch(head) and (expected_head is None or expected_head == head), "routine PR head changed during preparation")
    return head


def check_pr_source(source, base, head, online):
    candidate.git(source, "fetch", "--no-tags", "origin", head)
    common = candidate.git(source, "merge-base", base, head).decode().strip()
    _, after, changes, contracts = candidate.source_diff(source, common, head, routine=True)
    candidate.require(changes, "routine pull request has no patch changes")
    if online:
        candidate.release_records(changes, after, contracts)


def inspect(source, repository, base, login):
    branch, latest = default_state(source, repository)
    candidate.require(latest == base, "default branch moved; rerun preparation")
    rows = open_routine_prs(source, repository)
    if not rows:
        return {"mode": "new", "number": "", "head": ""}
    pr = rows[0]
    head = check_owner(pr, repository, branch, login)
    check_pr_source(source, base, head, online=True)
    return {"mode": "existing", "number": str(pr["number"]), "head": head}


def require_merge_rules(source, repository, branch):
    rules = api(source, f"repos/{repository}/rules/branches/{branch}")
    candidate.require(any(rule["type"] == "pull_request" for rule in rules), "auto-merge requires the protected PR path")
    status_rules = [rule["parameters"] for rule in rules if rule["type"] == "required_status_checks"]
    contexts = {check["context"] for rule in status_rules for check in rule["required_status_checks"]}
    candidate.require(REQUIRED_CHECKS <= contexts and any(rule.get("strict_required_status_checks_policy") for rule in status_rules),
                      "auto-merge requires Linux, macOS, secret and dependency checks with base freshness")


def request_merge(source, repository, branch, number, head, automatic):
    if automatic:
        require_merge_rules(source, repository, branch)
        run(source, "gh", "pr", "merge", str(number), "--repo", repository, "--auto", "--merge",
            "--delete-branch", "--match-head-commit", head)


def publish(source, repository, base, login, run_id, attempt, bundle=None, existing=None, expected_head=None, automatic=False):
    candidate.identity(repository, base, run_id, attempt)
    candidate.reference(source, base)
    branch, latest = default_state(source, repository)
    candidate.require(latest == base, "default branch moved; rerun preparation")
    remote = candidate.git(source, "remote", "get-url", "origin").decode().strip()
    candidate.require(remote in (f"https://github.com/{repository}", f"https://github.com/{repository}.git"), "publisher remote must be the selected GitHub repository")
    candidate.require(not candidate.git(source, "diff", "--name-only", base)
                      and not candidate.git(source, "ls-files", "--others", "--exclude-standard", "-z"), "publisher requires a clean trusted checkout")
    rows = open_routine_prs(source, repository)
    if existing:
        candidate.require(len(rows) == 1 and str(rows[0]["number"]) == existing, "prepared pull request is no longer current")
        pr = rows[0]
        head = check_owner(pr, repository, branch, login, expected_head)
        check_pr_source(source, base, head, online=False)
        common = candidate.git(source, "merge-base", base, head).decode().strip()
        if common != base:
            api(source, f"repos/{repository}/pulls/{existing}/update-branch", "PUT", {"expected_head_sha": head})
            return {"mode": "refresh-requested", "number": existing, "head": head}
        request_merge(source, repository, branch, existing, head, automatic)
        return {"mode": "existing", "number": existing, "head": head}

    candidate.require(not rows, "a routine pull request appeared; rerun preparation")
    after, changes = candidate.validate_bundle(bundle, source, base, repository, run_id, attempt)
    candidate.require(changes, "empty candidates cannot create a pull request")
    candidate.require(re.fullmatch(r"[A-Za-z0-9-]+\[bot\]", login or ""), "configure the expected App bot login")
    user = api(source, "users/" + login)
    candidate.require(user["login"] == login and user["type"] == "Bot" and type(user["id"]) is int, "App identity mismatch")
    email = f"{user['id']}+{login}@users.noreply.github.com"
    name = PREFIX + run_id  # A retry recovers this exact branch instead of adding a duplicate.
    occupied = api(source, f"repos/{repository}/git/ref/heads/{name}", missing=True)
    if occupied:
        head = occupied["object"]["sha"]
        candidate.require(candidate.COMMIT.fullmatch(head), "invalid recovery branch head")
        commit = api(source, f"repos/{repository}/commits/{head}")
        candidate.require(commit["author"]["login"] == login and commit["committer"]["login"] == login
                          and commit["commit"]["author"]["email"] == email and commit["commit"]["committer"]["email"] == email
                          and [parent["sha"] for parent in commit["parents"]] == [base], "occupied branch is not the expected App transaction")
        candidate.git(source, "fetch", "--no-tags", "origin", head)
        _, recovered, _, _ = candidate.source_diff(source, base, head, routine=True)
        candidate.require(recovered == after, "occupied branch contents differ from the prepared candidate")
    else:
        candidate.git(source, "config", "--local", "user.name", login)
        candidate.git(source, "config", "--local", "user.email", email)
        # The helper contains no token. gh reads the short-lived token from its environment.
        candidate.git(source, "config", "--local", "credential.helper", "")
        candidate.git(source, "config", "--local", "credential.https://github.com.helper", "!gh auth git-credential")
        if not (Path(source) / ".jj").exists():
            run(source, "jj", "git", "init", "--colocate")
        run(source, "jj", "config", "set", "--repo", "user.name", json.dumps(login))
        run(source, "jj", "config", "set", "--repo", "user.email", json.dumps(email))
        # Create the transaction after setting the App identity. An initial empty
        # change can retain the runner's previous author even after config changes.
        run(source, "jj", "new", base)
        for path in candidate.PATHS:
            if candidate.working_file(source, path) != after[path]:
                (Path(source) / path).write_bytes(after[path])
        run(source, "jj", "status", "--quiet")
        paths = [item["path"] for item in bundle["files"]]
        run(source, "jj", "commit", "-m", "chore: refresh verified tool patches", *paths)
        head = run(source, "jj", "log", "-r", "@-", "--no-graph", "--template", "commit_id").decode().strip()
        _, committed, _, _ = candidate.source_diff(source, base, head, routine=True)
        candidate.require(committed == after, "committed transaction differs from the checked candidate")
        run(source, "jj", "bookmark", "create", name, "-r", "@-")
        run(source, "bash", str(Path(source) / "dot_local/bin/executable_dotfiles-push"), "--bookmark", name, "--remote", "origin")

    # Check again after push. A moved default cannot use the stale preparation.
    candidate.require(default_state(source, repository) == (branch, base), "default branch moved after publication; rerun preparation to recover the branch")
    lines = ["Update verified tool patches within the current release lines.", "", "| Tool | Current | Target | Published |", "| --- | --- | --- | --- |"]
    for record in bundle["dependencies"]:
        lines.append(f"| {record['name']} | {record['current']} | {record['target']} | {record['publishedAt']} |")
    lines.extend(("", "Stable releases are at least seven days old. All four platform hashes were verified.",
                  f"Base: `{base}`. [Preparation run](https://github.com/{repository}/actions/runs/{run_id}).",
                  "", "Validation: focused preparation checks passed; required PR checks must pass before merge."))
    pr = api(source, f"repos/{repository}/pulls", "POST", {"head": name, "base": branch,
             "title": "chore: refresh verified tool patches", "body": "\n".join(lines)})
    number = str(pr["number"])
    check_owner(pr, repository, branch, login, head)
    request_merge(source, repository, branch, number, head, automatic)
    return {"mode": "created", "number": number, "head": head}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("inspect", "publish"))
    parser.add_argument("--source", default=".")
    parser.add_argument("--repository", default=os.environ.get("GITHUB_REPOSITORY"))
    parser.add_argument("--base", required=True)
    parser.add_argument("--login", required=True)
    parser.add_argument("--existing")
    parser.add_argument("--expected-head")
    parser.add_argument("--auto-merge", action="store_true")
    args = parser.parse_args()
    try:
        if args.operation == "inspect":
            result = inspect(args.source, args.repository, args.base, args.login)
        else:
            bundle = candidate.decode_json(base64.b64decode(os.environ.get("MAINTENANCE_CANDIDATE", ""), validate=True)) if not args.existing else None
            result = publish(args.source, args.repository, args.base, args.login, os.environ.get("GITHUB_RUN_ID"),
                             os.environ.get("GITHUB_RUN_ATTEMPT"), bundle, args.existing, args.expected_head, args.auto_merge)
        print(json.dumps(result))
        return 0
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f"Maintenance publication stopped: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
