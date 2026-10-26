#!/usr/bin/env python3
"""Close open pull requests that their base branch supersedes or that have no recent activity."""

import argparse
from datetime import datetime, timedelta, timezone
import html
import json
import os
import re
import subprocess

KEEP_LABEL = "keep-open"
DEPENDABOT = "dependabot[bot]"
BASE_REFS = "refs/outdated-prs/base/"
MERGE_TREE_CONFLICT = 1
REASONS = {
    "superseded": "The `{base}` branch already contains every change in this pull request.",
    "inactive": "This pull request has had no activity for {days} days.",
}


def run(*args, cwd=None):
    result = subprocess.run(args, cwd=cwd, capture_output=True, text=True, check=False)
    if result.returncode:
        raise SystemExit(f"{args[0]} {args[1]} failed: {result.stderr.strip()}")
    return result.stdout


def api(path, method="GET", fields=None):
    args = ["gh", "api", "--hostname", "github.com", path, "--method", method]
    for key, value in (fields or {}).items():
        args += ["-f", f"{key}={value}"]
    return json.loads(run(*args) or "null")


def open_prs(repository):
    pages = run("gh", "api", "--hostname", "github.com", "--paginate", "--slurp",
                f"repos/{repository}/pulls?state=open&per_page=100")
    prs = [pr for page in json.loads(pages) for pr in page]
    for pr in prs:
        if not re.fullmatch(r"[0-9a-f]{40}", pr["head"]["sha"]):
            raise SystemExit(f"pull request #{pr['number']} has an invalid head commit")
    return prs


def fetch(source, prs):
    bases = sorted({pr["base"]["ref"] for pr in prs})
    run("git", "fetch", "--no-tags", "--quiet", "origin",
        *(f"+refs/heads/{base}:{BASE_REFS}{base}" for base in bases),
        *sorted({pr["head"]["sha"] for pr in prs}), cwd=source)


def superseded(source, base, head):
    merge = subprocess.run(["git", "merge-tree", "--write-tree", base, head], cwd=source,
                           capture_output=True, text=True, check=False)
    if merge.returncode == MERGE_TREE_CONFLICT:
        return False
    if merge.returncode:
        raise SystemExit(f"git merge-tree failed: {merge.stderr.strip()}")
    merged_tree = merge.stdout.split()[0]
    base_tree = run("git", "rev-parse", f"{base}^{{tree}}", cwd=source).strip()
    return merged_tree == base_tree


def reason(source, pr, now, stale_days):
    if KEEP_LABEL in {label["name"] for label in pr["labels"]}:
        return None
    if superseded(source, BASE_REFS + pr["base"]["ref"], pr["head"]["sha"]):
        return "superseded"
    if pr["user"]["login"] == DEPENDABOT:
        return None  # Dependabot skips a version after its unmerged PR closes, which can drop a security fix.
    if now - datetime.fromisoformat(pr["updated_at"]) >= timedelta(days=stale_days):
        return "inactive"
    return None


def close(repository, pr, why, stale_days):
    path = f"repos/{repository}/pulls/{pr['number']}"
    current = api(path)
    if (current["state"], current["head"]["sha"], current["updated_at"]) != \
            ("open", pr["head"]["sha"], pr["updated_at"]):
        return "kept: it changed during the check"
    api(path, "PATCH", {"state": "closed"})
    text = REASONS[why].format(base=pr["base"]["ref"], days=stale_days)
    api(f"repos/{repository}/issues/{pr['number']}/comments", "POST", {"body": (
        f"{text} The `close-outdated-prs` workflow closed it automatically. "
        f"To keep a pull request open, reopen it and add the `{KEEP_LABEL}` label.")})
    return f"closed: {why}"


def review(source, repository, prs, now, stale_days, apply):
    if prs:
        fetch(source, prs)
    rows = []
    for pr in prs:
        why = reason(source, pr, now, stale_days)
        if why is None:
            result = "kept"
        elif apply:
            result = close(repository, pr, why, stale_days)
        else:
            result = f"would close: {why}"
        rows.append((pr["number"], pr["title"], result))
    return rows


def summary(rows, apply):
    lines = [f"Mode: {'close' if apply else 'report only'}", ""]
    if not rows:
        return "\n".join(lines + ["No open pull requests."]) + "\n"
    lines += ["| Pull request | Title | Result |", "| --- | --- | --- |"]
    for number, title, result in rows:
        title = html.escape(title).replace("|", "\\|")
        lines.append(f"| #{number} | {title} | {result} |")
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", default=os.environ.get("GITHUB_REPOSITORY"))
    parser.add_argument("--source", default=".")
    parser.add_argument("--stale-days", type=int, default=30)
    parser.add_argument("--apply", action="store_true", help="close outdated pull requests; the default only reports")
    parser.add_argument("--summary", help="append a Markdown report to this file")
    args = parser.parse_args()
    if not args.repository:
        parser.error("give --repository or set GITHUB_REPOSITORY")
    rows = review(args.source, args.repository, open_prs(args.repository),
                  datetime.now(timezone.utc), args.stale_days, args.apply)
    for number, _, result in rows:
        print(f"#{number}: {result}")
    if args.summary:
        with open(args.summary, "a", encoding="utf-8") as report:
            report.write(summary(rows, args.apply))


if __name__ == "__main__":
    main()
