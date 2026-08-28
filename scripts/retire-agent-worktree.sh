#!/bin/sh

set -eu

usage()
{
	cat <<'EOF'
usage: scripts/retire-agent-worktree.sh [--remove] WORKTREE

Audit a completed linked worktree. The default is a dry run. --remove retires
the worktree only when its branch is already contained in origin/main and the
worktree and all initialized submodules are clean.
EOF
}

die()
{
	printf 'refuse: %s\n' "$*" >&2
	exit 1
}

remove=false
case "$#" in
	1) target_arg=$1 ;;
	2)
		[ "$1" = --remove ] || { usage >&2; exit 2; }
		remove=true
		target_arg=$2
		;;
	*) usage >&2; exit 2 ;;
esac

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd -P)

git -C "$repo_root" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
	|| die "helper is not inside a Git worktree"
[ -d "$target_arg" ] || die "target is not a directory: $target_arg"
target=$(CDPATH= cd -- "$target_arg" && pwd -P) \
	|| die "cannot resolve target: $target_arg"
[ "$target" != "$repo_root" ] \
	|| die "invoke the helper from a retained checkout, not the target"

repo_common=$(git -C "$repo_root" rev-parse --path-format=absolute --git-common-dir)
target_common=$(git -C "$target" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) \
	|| die "target is not a Git worktree: $target"
repo_common=$(CDPATH= cd -- "$repo_common" && pwd -P)
target_common=$(CDPATH= cd -- "$target_common" && pwd -P)
[ "$repo_common" = "$target_common" ] \
	|| die "target belongs to a different Git repository: $target"

worktree_paths=$(git -C "$repo_root" worktree list --porcelain | sed -n 's/^worktree //p')
registered=false
primary=
while IFS= read -r path
do
	[ -n "$primary" ] || primary=$path
	[ "$path" != "$target" ] || registered=true
done <<EOF
$worktree_paths
EOF
[ "$registered" = true ] || die "target is not a registered worktree: $target"
[ "$target" != "$primary" ] || die "refusing the primary worktree: $target"

locked=$(git -C "$repo_root" worktree list --porcelain | awk -v target="$target" '
	$0 == "worktree " target { in_target = 1; next }
	/^worktree / { in_target = 0 }
	in_target && /^locked([[:space:]]|$)/ { print; exit }
')
[ -z "$locked" ] || die "worktree is locked: $target"

branch=$(git -C "$target" symbolic-ref --quiet --short HEAD 2>/dev/null) \
	|| die "detached worktrees require explicit review: $target"
[ "$branch" != main ] || die "refusing the main checkout: $target"

printf 'Refreshing origin/main...\n'
git -C "$repo_root" fetch --prune origin \
	|| die "could not refresh origin/main"
git -C "$repo_root" rev-parse --verify origin/main >/dev/null 2>&1 \
	|| die "origin/main is unavailable"

validate_clean()
{
	status=$(git -C "$target" status --porcelain=v2 --untracked-files=all \
		--ignore-submodules=none)
	[ -z "$status" ] || die "worktree has tracked, staged, submodule, or untracked changes: $target"
	git -C "$target" submodule foreach --recursive --quiet \
		'test -z "$(git status --porcelain=v2 --untracked-files=all)"' \
		>/dev/null 2>&1 \
		|| die "an initialized submodule is dirty: $target"
}

head=$(git -C "$target" rev-parse HEAD)
git -C "$repo_root" merge-base --is-ancestor "$head" origin/main \
	|| die "HEAD is not contained in origin/main: $branch ($head)"
validate_clean

size_kib=$(du -sk "$target" | awk '{ print $1 }')
submodule_count=$(git -C "$target" submodule foreach --recursive --quiet \
	'printf ".\\n"' | wc -l | tr -d ' ')
printf 'candidate\t%s\t%s\t%s\t%s KiB\t%s populated submodules\n' \
	"$target" "$branch" "$head" "$size_kib" "$submodule_count"

[ "$remove" = true ] || {
	printf 'dry-run only; rerun with --remove after reviewing this candidate\n'
	exit 0
}

# Revalidate immediately before the destructive operation. A populated clean
# submodule makes Git require --force even though neither tree is dirty; the
# preceding checks keep that override scoped to this one audited condition.
validate_clean
head_now=$(git -C "$target" rev-parse HEAD)
[ "$head_now" = "$head" ] || die "HEAD changed during audit: $target"
git -C "$repo_root" merge-base --is-ancestor "$head_now" origin/main \
	|| die "HEAD stopped being an ancestor of origin/main: $target"

if [ "$submodule_count" -gt 0 ]; then
	git -C "$repo_root" worktree remove --force "$target"
else
	git -C "$repo_root" worktree remove "$target"
fi
git -C "$repo_root" worktree prune --expire now --verbose
git -C "$repo_root" show-ref --verify --quiet "refs/heads/$branch" \
	|| die "worktree was removed but its branch ref is unexpectedly missing: $branch"
printf 'removed\t%s\tbranch-preserved:%s\t%s KiB\n' \
	"$target" "$branch" "$size_kib"
