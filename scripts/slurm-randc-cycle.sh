#!/usr/bin/env bash
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=00:30:00
# Replay the full sparse randc cycle from a clean local branch snapshot.
set -euo pipefail

run_job() {
	local run_dir=${SLURM_SUBMIT_DIR:?}
	local rootfs="$run_dir/deps/root"
	local build_source="$run_dir/build/source"
	local edition

	mkdir -p "$rootfs" "$run_dir/build" "$run_dir/install" "$run_dir/results"
	for package in "$run_dir"/debs/*.deb; do
		dpkg-deb -x "$package" "$rootfs"
	done
	cp -a "$run_dir/source" "$build_source"
	export PATH="$rootfs/usr/bin:$PATH"
	export CPPFLAGS="-I$rootfs/usr/include ${CPPFLAGS:-}"
	export LDFLAGS="-L$rootfs/usr/lib/x86_64-linux-gnu -L$rootfs/usr/lib ${LDFLAGS:-}"
	export LD_LIBRARY_PATH="$rootfs/usr/lib/x86_64-linux-gnu:$rootfs/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
	export AC_MACRODIR="$rootfs/usr/share/autoconf"
	export AUTOM4TE="$rootfs/usr/bin/autom4te"
	export AUTOM4TE_CFG="$run_dir/deps/autom4te.cfg"
	export autom4te_perllibdir="$rootfs/usr/share/autoconf"
	export trailer_m4="$rootfs/usr/share/autoconf/autoconf/trailer.m4"
	# Relocate Autoconf's configured data prefix into the extracted package tree.
	sed "s|/usr/share/autoconf|$rootfs/usr/share/autoconf|g" \
		"$rootfs/usr/share/autoconf/autom4te.cfg" > "$AUTOM4TE_CFG"

	cd "$build_source"
	autoconf -f
	./configure --prefix="$run_dir/install"
	make -j "${SLURM_CPUS_PER_TASK:-1}"
	make install

	for edition in 2017 2023; do
		"$run_dir/install/bin/iverilog" -g"$edition" -s test \
			-o "$run_dir/results/full-cycle-$edition.vvp" \
			"$run_dir/source/evidence/ieee-randc-domain-cap-20261009/standalone-full-cycle.sv"
		"$run_dir/install/bin/vvp" "$run_dir/results/full-cycle-$edition.vvp" \
			| tee "$run_dir/results/full-cycle-$edition.log"
		grep -qx PASSED "$run_dir/results/full-cycle-$edition.log"
	done
}

if [[ ${1:-} == --job ]]; then
	run_job
	exit
fi

if (( $# != 1 )); then
	echo "usage: $0 <local-branch>" >&2
	exit 2
fi

branch=$1
repo=$(cd "$(dirname "$0")/.." && pwd)
git -C "$repo" check-ref-format --branch "$branch" >/dev/null
if ! commit=$(git -C "$repo" rev-parse --verify "refs/heads/$branch^{commit}" 2>/dev/null); then
	echo "no local branch named '$branch'" >&2
	exit 2
fi
branch_worktree=$(git -C "$repo" worktree list --porcelain | awk \
	-v ref="refs/heads/$branch" \
	'$1 == "worktree" { path = substr($0, 10) }
	 $1 == "branch" && $2 == ref { print path; exit }')
if [[ -n $branch_worktree ]] \
	&& [[ -n $(git -C "$branch_worktree" status --ignore-submodules=none --porcelain --untracked-files=all) ]]; then
	echo "branch worktree must be clean; commit or remove local changes first" >&2
	exit 2
fi

run_id="$(date -u +%Y%m%dT%H%M%SZ)-${commit:0:8}-$$"
remote_home=$(ssh DAN-DESKTOP 'printf %s "$HOME"')
remote_dir="$remote_home/slurm-runs/iverilog-uvm/codex-420/$run_id"
ssh DAN-DESKTOP "mkdir -p '$remote_home/slurm-runs/iverilog-uvm/codex-420' && mkdir '$remote_dir' && mkdir '$remote_dir/source' '$remote_dir/debs' '$remote_dir/logs'"
git -C "$repo" archive --format=tar "$commit" \
	| ssh DAN-DESKTOP "tar -xf - -C '$remote_dir/source'"
printf '%s\n' "$commit" \
	| ssh DAN-DESKTOP "cat > '$remote_dir/source.commit'"
ssh DAN-DESKTOP "cd '$remote_dir/debs' && apt-get download make autoconf gperf bison flex m4 debianutils libz3-dev libz3-4 libffi-dev libffi8 libfl2 && sha256sum *.deb > SHA256SUMS"

job_id=$(ssh DAN-DESKTOP "cd '$remote_dir' && sbatch --parsable --partition=verilog --job-name='randc-cycle-$run_id' --chdir='$remote_dir' --output='$remote_dir/logs/%x-%j.out' source/scripts/slurm-randc-cycle.sh --job")
printf 'commit=%s\nrun_dir=%s\njob_id=%s\nlog=%s/logs/randc-cycle-%s-%s.out\n' \
	"$commit" "$remote_dir" "$job_id" "$remote_dir" "$run_id" "$job_id"
