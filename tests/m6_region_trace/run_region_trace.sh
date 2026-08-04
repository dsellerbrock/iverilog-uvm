#!/usr/bin/env bash
# M6 region-tagging trace verification (scheduler remediation item 1).
# Compiles a small design that exercises the Active, Inactive, NBA and
# Postponed regions within one time slot, runs it with IVL_REGION_TRACE=1,
# and asserts that:
#   1. every event reports its true IEEE 1800-2017 clause-4 region tag
#      (an event promoted wholesale into the active queue still reports
#      the region it was scheduled into — e.g. Inactive, not Active);
#   2. the regions appear in the stratified drain order within the slot
#      (Active/Inactive design regions, then NBA, then Postponed);
#   3. the first instruction of a child forked by a program process stays
#      in the Reactive region inherited from its parent.
# This is the durable regression for the region-tag machinery itself;
# behavioral ordering is covered by tests/m6_sched_litmus_test.sv.
#
# Usage: PATH=<install>/bin:$PATH bash tests/m6_region_trace/run_region_trace.sh

set -u
BIN=$(which iverilog)
VVP=$(which vvp)
DIR=$(dirname "$0")
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/dut.sv" <<'EOF'
module top;
  reg a;
  reg [7:0] nb;
  initial begin
    a = 0;
    nb <= 8'hAA;      // NBA region
    #0 a = 1;         // Inactive region (deferred continuation)
    $strobe("s");     // Postponed (ROSync) region
    $finish;
  end
endmodule
EOF

if ! "$BIN" -g2012 -o "$WORK/dut.vvp" "$WORK/dut.sv" 2>"$WORK/cerr"; then
    echo "FAIL: compile error"; cat "$WORK/cerr"; exit 1
fi

# Collect the ordered list of region tags emitted by the trace.
IVL_REGION_TRACE=1 "$VVP" "$WORK/dut.vvp" 2>"$WORK/trace" >/dev/null
seq=$(grep -oE 'REGION @ [0-9]+ ps [A-Za-z-]+' "$WORK/trace" \
        | sed -E 's/.* ps //' | tr '\n' ' ')

echo "  region sequence: $seq"

fail=0
check() { # marker present
    if ! echo "$seq" | grep -q "$1"; then
        echo "  FAIL: expected region '$1' in trace"; fail=1
    fi
}
check "Active"
check "Inactive"
check "NBA"
check "ROSync"

# Ordering: the first NBA must come before the first ROSync, and the
# first Inactive (deferred #0 continuation) before the first NBA.
pos() { echo "$seq" | tr ' ' '\n' | grep -n "^$1$" | head -1 | cut -d: -f1; }
p_inact=$(pos Inactive); p_nba=$(pos NBA); p_ro=$(pos ROSync)
if [ -n "$p_inact" ] && [ -n "$p_nba" ] && [ "$p_inact" -gt "$p_nba" ]; then
    echo "  FAIL: Inactive ($p_inact) after NBA ($p_nba)"; fail=1
fi
if [ -n "$p_nba" ] && [ -n "$p_ro" ] && [ "$p_nba" -gt "$p_ro" ]; then
    echo "  FAIL: NBA ($p_nba) after ROSync ($p_ro)"; fail=1
fi

# --- Part 2: Preponed / Observed region ordering (M6 item 4) ------------
# The self-test injects one no-op into each delay-permitting region in
# REVERSE order; a correct pipeline drains them in forward IEEE order,
# proving Preponed runs before Active and Observed after NBA / before
# Reactive.
cat > "$WORK/tick.sv" <<'EOF'
module top; initial #2 $finish; endmodule
EOF
if ! "$BIN" -g2012 -o "$WORK/tick.vvp" "$WORK/tick.sv" 2>"$WORK/cerr2"; then
    echo "FAIL: compile error (part 2)"; cat "$WORK/cerr2"; exit 1
fi
IVL_REGION_TRACE=1 IVL_REGION_SELFTEST=1 "$VVP" "$WORK/tick.vvp" \
    2>"$WORK/trace2" >/dev/null
seq2=$(grep -E 'REGION.*selftest' "$WORK/trace2" \
        | sed -E 's/.* ps ([A-Za-z-]+): selftest.*/\1/' | tr '\n' ' ')
echo "  selftest region order: $seq2"

expected="Preponed Active NBA NBASync Observed Reactive Re-NBA RWSync ROSync "
if [ "$seq2" != "$expected" ]; then
    echo "  FAIL: expected '$expected' got '$seq2'"; fail=1
fi

# --- Part 3: program fork first-instruction region -----------------------
# A program initial process starts in Reactive.  Its fork child must inherit
# that affinity before the child's FIRST instruction runs; checking only a
# continuation after a delay would miss a schedule_vthread(..., push=true)
# bug that briefly puts the new child into Active.
cat > "$WORK/reactive_fork.sv" <<'EOF'
module fork_region_top;
  bit child_ran;
  initial #10 $finish;
endmodule

program fork_region_prog;
  initial begin
    fork : reactive_first_instruction
      fork_region_top.child_ran = 1'b1;
    join
    if (!fork_region_top.child_ran)
      $fatal(1, "fork child did not run");
    $finish;
  end
endprogram
EOF
if ! "$BIN" -g2012 -o "$WORK/reactive_fork.vvp" \
        "$WORK/reactive_fork.sv" 2>"$WORK/cerr3"; then
    echo "FAIL: compile error (part 3)"; cat "$WORK/cerr3"; exit 1
fi
IVL_REGION_TRACE=1 "$VVP" "$WORK/reactive_fork.vvp" \
    2>"$WORK/trace3" >/dev/null
fork_resume=$(grep -m1 -E \
    'REGION @ .* ps [A-Za-z-]+: vthread_event: Resume thread scope=.*reactive_first_instruction' \
    "$WORK/trace3")
fork_region=$(echo "$fork_resume" \
    | sed -E 's/.* ps ([A-Za-z-]+): vthread_event.*/\1/')
echo "  program fork first-instruction region: ${fork_region:-<missing>}"
if [ -z "$fork_resume" ]; then
    echo "  FAIL: no resume trace found for program fork child"; fail=1
elif [ "$fork_region" != "Reactive" ]; then
    echo "  FAIL: program fork child first ran in '$fork_region', expected 'Reactive'"
    fail=1
fi

if [ "$fail" -eq 0 ]; then
    echo "PASS"
    exit 0
fi
echo "--- trace ---"; cat "$WORK/trace"
echo "--- trace2 ---"; cat "$WORK/trace2"
echo "--- trace3 ---"; cat "$WORK/trace3"
exit 1
