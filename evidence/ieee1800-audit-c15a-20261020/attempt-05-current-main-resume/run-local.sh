#!/bin/bash
set -euo pipefail
REPO=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm
EVDIR="$REPO/evidence/ieee1800-audit-c15a-20261020/attempt-05-current-main-resume"
BUILD=/tmp/a3-main-c41e-c15a-20261020-01
SOURCE="$BUILD/source"
INSTALL="$BUILD/install"
COMMIT=c41e504c7ee64a7bfc047f8662d3bc8044f1d90f
PROBES="$REPO/tests/1800_audit/c15"
test "$(cat "$REPO/evidence/ieee1800-audit-c15a-20261020/attempt-04-current-main/source-commit.txt")" = "$COMMIT"
mkdir -p "$EVDIR/logs"
export PATH="/opt/homebrew/opt/bison/bin:$PATH"
cd "$SOURCE"
make -j3 CXXFLAGS='-Wall -Wextra -Wshadow -g -O2 -std=c++11 -I/opt/homebrew/opt/libffi/include' LDFLAGS='-Wl,-all_load -L/opt/homebrew/opt/libffi/lib' > "$EVDIR/logs/build-resume.log" 2>&1
make install > "$EVDIR/logs/install.log" 2>&1
IVL="$INSTALL/bin/iverilog"
VVP="$INSTALL/bin/vvp"
"$IVL" -V > "$EVDIR/iverilog-version.txt" 2>&1
printf 'compiler/vvp sha256:\n' > "$EVDIR/toolchain.sha256"
shasum -a 256 "$IVL" "$VVP" >> "$EVDIR/toolchain.sha256"
printf 'edition\tprobe\tcompile_rc\trun_rc\n' > "$EVDIR/results.tsv"
run_timed() { python3 "$SOURCE/scripts/run_with_timeout.py" 20 -- "$@"; }

for g in 2017 2023; do
  for spec in 'positive:p15_04a_mailbox' 'waiter_reduction:r15_04b_waiter_assignment' 'runtime_mismatch:r15_get_mismatch'; do
    kind=${spec%%:*}
    name=${spec#*:}
    log="$EVDIR/logs/$name-g$g.log"
    if run_timed "$IVL" -g"$g" -o "$EVDIR/$name-g$g.vvp" "$PROBES/$name.sv" > "$log" 2>&1; then crc=0; else crc=$?; fi
    rrc=NA
    if [ "$crc" -eq 0 ]; then
      if run_timed "$VVP" "$EVDIR/$name-g$g.vvp" >> "$log" 2>&1; then rrc=0; else rrc=$?; fi
    fi
    printf '%s\t%s\t%s\t%s\n' "$g" "$kind" "$crc" "$rrc" >> "$EVDIR/results.tsv"
  done
  for name in n15_param_put_int n15_param_get_int; do
    log="$EVDIR/logs/$name-g$g.log"
    if run_timed "$IVL" -g"$g" -o "$EVDIR/$name-g$g.vvp" "$PROBES/neg/$name.sv" > "$log" 2>&1; then crc=0; else crc=$?; fi
    printf '%s\t%s\t%s\tNA\n' "$g" "$name" "$crc" >> "$EVDIR/results.tsv"
  done
done
cat "$EVDIR/results.tsv"
