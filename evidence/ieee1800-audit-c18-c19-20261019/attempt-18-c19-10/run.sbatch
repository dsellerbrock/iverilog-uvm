#!/usr/bin/env bash
#SBATCH --job-name=a3-audit-c19-10-r2
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:20:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/A3/audit-c19-10-20261019-18/logs/%x-%j.out
set -uo pipefail

RUN=/home/dsell/slurm-runs/iverilog-uvm/A3/audit-c19-10-20261019-18
TOOL=/home/dsell/toolchains/iverilog-a3-main-82023726-679
IVL="$TOOL/bin/iverilog"
VVP="$TOOL/bin/vvp"
RESULTS="$RUN/results"
mkdir -p "$RESULTS" "$RUN/logs"
cd "$RUN"

if [[ ! -s input/c19.10-probes.tar.gz ]]; then
  echo "missing input/c19.10-probes.tar.gz" >&2
  exit 2
fi
sha256sum input/c19.10-probes.tar.gz > "$RESULTS/input-archive.sha256"
tar -xzf input/c19.10-probes.tar.gz -C input || exit 2
sha256sum input/*.sv input/neg/*.sv > "$RESULTS/input.sha256"
{
  date -Is
  hostname
  uname -a
  printf 'RUN=%s\nTOOL=%s\nIVL=%s\nVVP=%s\n' "$RUN" "$TOOL" "$IVL" "$VVP"
  sha256sum "$IVL" "$VVP" "$TOOL/lib/ivl/ivl"
  "$IVL" -B "$TOOL/lib/ivl" -V 2>&1
  "$VVP" -V 2>&1
} > "$RESULTS/environment.txt"
: > "$RESULTS/observations.txt"

timed() {
  local name="$1" rc
  shift
  printf '%q ' "$@" > "$RESULTS/$name.command"
  printf '\n' >> "$RESULTS/$name.command"
  if /usr/bin/time -f 'wall_s=%e peak_rss_kib=%M' -o "$RESULTS/$name.time" \
      timeout -k 5s 60s "$@" > "$RESULTS/$name.log" 2>&1; then
    rc=0
  else
    rc=$?
  fi
  printf '%s\n' "$rc" > "$RESULTS/$name.exit"
}

positive() {
  local edition="$1" rc base
  base="$RESULTS/option-structs-$edition"
  timed "option-structs-$edition-compile" "$IVL" -B "$TOOL/lib/ivl" -g"$edition" \
    -s test "$RUN/input/p19_10_option_structs.sv" -o "$base.vvp"
  rc=$(cat "$RESULTS/option-structs-$edition-compile.exit")
  if [[ "$rc" == 0 ]]; then
    timed "option-structs-$edition-run" "$VVP" -n "$base.vvp"
    rc=$(cat "$RESULTS/option-structs-$edition-run.exit")
    if [[ "$rc" == 0 ]] && grep -Fq 'PASS 19.10 option structure organization' "$RESULTS/option-structs-$edition-run.log"; then
      printf 'option-structs-%s=PASS\n' "$edition" >> "$RESULTS/observations.txt"
    else
      printf 'option-structs-%s=RUN_FAIL(exit=%s)\n' "$edition" "$rc" >> "$RESULTS/observations.txt"
    fi
  else
    printf 'option-structs-%s=COMPILE_FAIL(exit=%s)\n' "$edition" "$rc" >> "$RESULTS/observations.txt"
  fi
}

procedural_members() {
  local edition="$1" rc base
  base="$RESULTS/procedural-members-$edition"
  timed "procedural-members-$edition-compile" "$IVL" -B "$TOOL/lib/ivl" -g"$edition" \
    -s test_proc_members "$RUN/input/p19_10_procedural_members.sv" -o "$base.vvp"
  rc=$(cat "$RESULTS/procedural-members-$edition-compile.exit")
  if [[ "$rc" == 0 ]]; then
    timed "procedural-members-$edition-run" "$VVP" -n "$base.vvp"
    rc=$(cat "$RESULTS/procedural-members-$edition-run.exit")
    if [[ "$rc" == 0 ]] && grep -Fq 'PASS 19.10 procedural goal and comment writes' "$RESULTS/procedural-members-$edition-run.log"; then
      printf 'procedural-members-%s=PASS\n' "$edition" >> "$RESULTS/observations.txt"
    else
      printf 'procedural-members-%s=RUN_FAIL(exit=%s)\n' "$edition" "$rc" >> "$RESULTS/observations.txt"
    fi
  else
    printf 'procedural-members-%s=COMPILE_FAIL(exit=%s)\n' "$edition" "$rc" >> "$RESULTS/observations.txt"
  fi
}

negative() {
  local edition="$1" rc
  timed "nonexistent-member-$edition-compile" "$IVL" -B "$TOOL/lib/ivl" -g"$edition" \
    -tnull "$RUN/input/neg/n19_10_nonexistent_option.sv"
  rc=$(cat "$RESULTS/nonexistent-member-$edition-compile.exit")
  if [[ "$rc" != 0 ]]; then
    printf 'nonexistent-member-%s=REJECTED(exit=%s)\n' "$edition" "$rc" >> "$RESULTS/observations.txt"
  else
    printf 'nonexistent-member-%s=ACCEPTED\n' "$edition" >> "$RESULTS/observations.txt"
  fi
}

positive 2017
positive 2023
procedural_members 2017
procedural_members 2023
negative 2017
negative 2023
printf 'AUDIT_PROBE_COMPLETE=yes\n' | tee "$RESULTS/RESULT.txt"
