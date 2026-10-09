#!/usr/bin/env python3
"""Merge the current main branch into each open, in-repository PR."""

import json
import os
import subprocess
import sys
import tempfile
from collections import defaultdict


# These files describe the campaign's current state; preserve main where edits overlap.
MAIN_WINS = {
    ".ai/ACTIVE_WORK.yaml",
    ".ai/CAMPAIGN.yaml",
    ".ai/ISSUE_CHECKOUT.csv",
    "docs/conformance/BLOCKERS.md",
    "docs/conformance/CURRENT_WORK.md",
    "docs/conformance/DISCOVERED_DEBT.md",
    "docs/conformance/matrices/ieee1800_2017_clause_matrix.md",
    "docs/conformance/ieee1800_2023_delta.md",
}


def run(args, *, check=True, data=None, binary=False):
    result = subprocess.run(
        args,
        input=data,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=not binary,
    )
    if check and result.returncode:
        stderr = result.stderr.decode(errors="replace") if binary else result.stderr
        raise RuntimeError(f"{args[0]} failed: {stderr.strip()}")
    return result


def git(*args, **kwargs):
    return run(["git", *args], **kwargs)


def gh(*args, **kwargs):
    return run(["gh", *args], **kwargs)


def quote(value):
    return (
        str(value)
        .replace("\r", " ")
        .replace("\n", " ")
        .replace("|", "\\|")
        .replace("`", "\\`")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
    )


def record(rows, number, branch, result):
    rows.append((number, branch, result))
    print(f"PR #{quote(number)} ({quote(branch)}): {quote(result)}")


def load_prs(repo, only_number):
    if only_number:
        if not only_number.isdecimal():
            raise RuntimeError("pull_request input must be a PR number")
        return [json.loads(gh("api", f"repos/{repo}/pulls/{only_number}").stdout)]

    pages = json.loads(
        gh(
            "api",
            "--paginate",
            "--slurp",
            f"repos/{repo}/pulls?state=open&base=main&per_page=100",
        ).stdout
    )
    return [pr for page in pages for pr in page]


def conflicts():
    raw = git("ls-files", "-u", "-z", binary=True).stdout
    grouped = defaultdict(dict)
    for item in raw.split(b"\0"):
        if not item:
            continue
        metadata, path = item.split(b"\t", 1)
        mode, oid, stage = metadata.split()
        grouped[os.fsdecode(path)][int(stage)] = (mode.decode(), oid.decode())
    return grouped


def blob(oid):
    return git("cat-file", "blob", oid, binary=True).stdout


def set_index(path, mode, oid):
    git("update-index", "--force-remove", "--", path, check=False)
    if mode is None:
        git("rm", "-f", "--ignore-unmatch", "--", path, check=False)
        return
    git("update-index", "--add", "--cacheinfo", f"{mode},{oid},{path}")
    if mode != "160000":
        git("checkout-index", "--force", "--", path)


def resolve_conflicts():
    entries = conflicts()
    for path, stages in entries.items():
        prefer_main = path in MAIN_WINS
        preferred_stage, other_stage = (3, 2) if prefer_main else (2, 3)
        preferred = stages.get(preferred_stage)
        other = stages.get(other_stage)
        base = stages.get(1)

        if preferred is None:
            set_index(path, None, None)
            continue

        # For ordinary text files, merge non-overlapping hunks and choose the
        # preferred side only where the edits overlap.
        mergeable = (
            base is not None
            and other is not None
            and all(item[0] in ("100644", "100755") for item in (base, preferred, other))
        )
        if mergeable:
            preferred_data = blob(preferred[1])
            base_data = blob(base[1])
            other_data = blob(other[1])
            mergeable = not any(b"\0" in content for content in (preferred_data, base_data, other_data))

        if mergeable:
            with tempfile.TemporaryDirectory() as temp_dir:
                preferred_path = os.path.join(temp_dir, "preferred")
                base_path = os.path.join(temp_dir, "base")
                other_path = os.path.join(temp_dir, "other")
                for filename, content in (
                    (preferred_path, preferred_data),
                    (base_path, base_data),
                    (other_path, other_data),
                ):
                    with open(filename, "wb") as stream:
                        stream.write(content)
                merged = run(
                    [
                        "git", "merge-file", "--stdout", "--ours",
                        "-L", "preferred", "-L", "base", "-L", "other",
                        preferred_path, base_path, other_path,
                    ],
                    check=False,
                    binary=True,
                )
            if merged.returncode not in (0, 1):
                raise RuntimeError(f"could not auto-resolve text conflict in {path}")
            oid = git("hash-object", "-w", "--stdin", data=merged.stdout, binary=True).stdout.strip().decode()
            set_index(path, preferred[0], oid)
        else:
            # Add/delete, binary, symlink, and gitlink conflicts use the
            # same explicit side preference without running repository code.
            set_index(path, preferred[0], preferred[1])

        policy = "main" if prefer_main else "PR"
        print(f"  auto-resolved {path} ({policy} wins overlapping edits)")

    if conflicts():
        raise RuntimeError("unmerged paths remain after automatic conflict resolution")
    return len(entries)


def reset_to_main():
    git("merge", "--abort", check=False)
    git("reset", "--hard", "origin/main")
    git("clean", "-ffd")
    git("switch", "--detach", "origin/main")


def write_summary(rows):
    path = os.environ.get("GITHUB_STEP_SUMMARY")
    if not path:
        return
    with open(path, "a", encoding="utf-8") as summary:
        summary.write("## PR branch synchronization\n\n")
        summary.write("| PR | Branch | Result |\n|---:|---|---|\n")
        for number, branch, result in rows:
            summary.write(f"| #{number} | `{quote(branch)}` | {quote(result)} |\n")


def main():
    repo = os.environ["GITHUB_REPOSITORY"]
    only_number = os.environ.get("PR_NUMBER", "").strip()
    rows = []
    failures = 0

    git("config", "user.name", "github-actions[bot]")
    git("config", "user.email", "41898282+github-actions[bot]@users.noreply.github.com")
    git("fetch", "--no-tags", "origin", "+refs/heads/main:refs/remotes/origin/main")
    prs = load_prs(repo, only_number)

    for pr in prs:
        number = pr["number"]
        branch = pr["head"]["ref"]
        head_repo = pr["head"].get("repo")
        if pr["state"] != "open" or pr["base"]["ref"] != "main":
            record(rows, number, branch, "skipped (not an open PR to main)")
            continue
        if not head_repo or head_repo["full_name"].lower() != repo.lower():
            record(rows, number, branch, "skipped (fork branches are read-only)")
            continue
        if branch == "main" or git("check-ref-format", "--branch", branch, check=False).returncode:
            record(rows, number, branch, "skipped (invalid or base branch ref)")
            continue

        reset_to_main()
        ref = f"refs/remotes/pr-sync/{number}"
        try:
            git("fetch", "--no-tags", "origin", f"+refs/heads/{branch}:{ref}")
            head_sha = git("rev-parse", ref).stdout.strip()
            if head_sha != pr["head"]["sha"]:
                record(rows, number, branch, "skipped (head changed during sync; retry next run)")
                continue
            ancestry = git("merge-base", "--is-ancestor", "origin/main", ref, check=False)
            if ancestry.returncode == 0:
                record(rows, number, branch, "already up to date")
                continue
            if ancestry.returncode != 1:
                raise RuntimeError("could not compare the PR branch with main")

            git("switch", "--detach", ref)
            merge = git("merge", "--no-commit", "--no-ff", "origin/main", check=False)
            if merge.returncode:
                if not conflicts():
                    raise RuntimeError(merge.stderr.strip() or "main merge failed")
                resolved = resolve_conflicts()
            else:
                resolved = 0

            git("commit", "-m", f"Merge origin/main into PR #{number}")
            synced_sha = git("rev-parse", "HEAD").stdout.strip()
            git("push", "origin", f"HEAD:refs/heads/{branch}")
            gh("workflow", "run", "test.yml", "--repo", repo, "--ref", branch)
            result = f"updated; full CI dispatched at {synced_sha[:12]}"
            if resolved:
                result += f"; auto-resolved {resolved} conflict path(s)"
            record(rows, number, branch, result)
        except Exception as error:  # keep processing the other open PRs
            failures += 1
            record(rows, number, branch, f"failed: {error}")

    if not prs:
        rows.append(("—", "—", "no open PRs target main"))
    write_summary(rows)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
