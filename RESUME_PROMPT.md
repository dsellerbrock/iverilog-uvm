# Resume Prompt — UVM/iverilog OpenTitan UART DV

Copy this entire block into a fresh Claude Code session at
`/home/daniel/uvm_iverilog/`.

---

I'm continuing work on an experimental fork of Icarus Verilog that adds
SystemVerilog/UVM support good enough to run OpenTitan's `uart_smoke_vseq` DV
testbench end-to-end. The repo is at `/home/daniel/uvm_iverilog/`. The
iverilog source tree is `iverilog/`, the OpenTitan fork is `opentitan/`,
the UVM core is at `accellera-official.uvm-core/`, and reproducer tests
live in `tests/`.

## Current state

This file is the **session-resume / onboarding workflow** — how to pick the work back up.
For the authoritative current status (sv-tests, canonical UVM, OpenTitan, gap list), read the
single canonical source: **`IEEE1800_UVM_SUPPORT.md`**. Do not restate pass-rates here — they
drift. As of the last session: development @ Phase 87; the **#1 open target** is the OpenTitan
plateau (`wait(assoc[k].class_member)` never wakes — see `IEEE1800_UVM_SUPPORT.md` §2.3).

**Build/install gotcha:** `iverilog/install/bin/iverilog` invokes `iverilog/install/lib/ivl/ivl`, not `iverilog/install/bin/ivl`.  After rebuilding always use `bash iverilog/scripts/install_ivl.sh`; `tgt-vvp/vvp.tgt` must also be copied (the install script does this; `make install` alone does not).

**Cleanup discipline (2026-05-10):** `/tmp` is tmpfs on this box.  Clean per-test work dirs (`canon_*`, stale `.vvp`) after extracting the verdict — accumulation pushes physical RAM into swap and gets vvp OOM-killed.  Wrap heavy runs with `/tmp/memlimit.sh MEM_MB WALL_SEC -- cmd` (uses `prlimit --as` + `timeout`).

## What to work on next

**Priority queue (descending):**

1. **Deferred PR enhancements** (`https://github.com/dsellerbrock/iverilog-uvm/pulls?state=closed` — PRs #63/#64/#65 closed in Phase 83): `foreach (aa[k1, k2])` 2D-assoc write codegen, `array.unique()`, unpacked-array `sort()/rsort()/reverse()`, enum `next()/prev()` chain on lvalue.  None gate current sv-tests but each adds real SV coverage.

2. **SVA `[->N:M]` / `[=N:M]` full semantics** (gap accounting for non-consecutive matches).  P84 approximates these as `[*N:M]` (consecutive); semantically not exact for tests that depend on gap behaviour.  No current sv-test exercises this distinction.

3. **OT UART smoke vseq throughput.**  Phase 61 stack got us from a 30 µs hang to ~1.76 ms in 2 hours wallclock.  Closing the gap to "Finished test sequence" is throughput-bound, not bug-bound — needs iverilog event-loop work (lock-free scheduler, JIT, or similar).  Multi-week project.

4. **Push current development to private remote**.  Development is ahead of `private/development` by P74-P84 work.

### Historical issue notes (superseded — verify before reopening)

The original issues #29 (Phase 58 vif `wait()` chain), #30 (Phase 59 `try_next_item`), #31 (Phase 60 `cfg` null-after-fork) were tracked in detail in earlier revisions of this prompt.  Memory records (`MEMORY.md`) indicate these areas have moved forward through the Phase 58/59 ship + Phase 61 stack; the status sections in `MEMORY.md` are authoritative.  Before opening a fresh repro on any of them, `git log` the relevant subsystem (`iverilog/net_nex_input.cc`, `iverilog/elaborate.cc`, `iverilog/vvp/vthread.cc`) and re-run the linked test to see the real current behaviour.

## How I work in this codebase

- **Reproducers first.** Build a focused `tests/<name>_test.sv` that
  exhibits the bug in 30-50 lines before touching iverilog source. The
  OpenTitan stack is too big for fast iteration.
- **Use the advisor tool aggressively.** Before committing to an approach
  on something multi-layer, call advisor. It can save a multi-hour rabbit
  hole. The advisor pulled me out of a deep elaboration-time scope-walk
  that wouldn't have worked.
- **Don't punt to a hack workaround if you'd be doing it for the third
  time on the same shape.** Phase 57 (OT-side tl_monitor patch) is the only
  workaround in the iverilog-uvm OT branch and it's there because the real
  fix is multi-layer. Avoid accumulating these.
- **Memory.** `~/.claude/projects/-home-daniel-uvm-iverilog/memory/MEMORY.md`
  has the full phase history. Read the top section first. Don't rewrite it;
  prepend new status under "Current Status (as of YYYY-MM-DD)".
- **Build/test workflow:**
  ```bash
  cd /home/daniel/uvm_iverilog
  make -C iverilog -j4 && make -C iverilog install
  # canonical regression:
  for t in pre_post_randomize_test cfg_aa_read_test wait_clks_test \
           iface_late_apply_test no_rand_test simple_rand_test \
           constraint_test; do
    iverilog/install/bin/iverilog -g2012 -o /tmp/$t.vvp tests/$t.sv 2>/dev/null
    timeout 5 iverilog/install/bin/vvp /tmp/$t.vvp 2>&1 | grep -E 'PASS|FAIL'
  done
  # OpenTitan UART DV:
  bash scripts/compile_uart_dv.sh
  timeout 200 iverilog/install/bin/vvp /tmp/uart_dv.vvp \
    +UVM_TESTNAME=uart_base_test +UVM_TEST_SEQ=uart_smoke_vseq \
    +UVM_VERBOSITY=UVM_LOW > /tmp/dv.log 2>&1
  grep -E 'ERROR|FATAL|TEST PASSED|TEST FAILED' /tmp/dv.log | head -10
  ```
- **Don't add comments that say what code does** — the code already does.
  Add a comment only when the *why* is non-obvious (e.g. "Phase 56: SV `!x`
  produces 1-bit, not Bool — Z3_mk_not requires Bool" is the *why*; the
  code itself is the *what*). The advisor enforces this.
- **Phase numbering.** Pick the next free number. Do not retroactively
  renumber. Don't combine multiple phases in one commit unless they fix the
  same root cause from different angles (Phase 50d/e/f did this for the
  freq=0 cascade).
- **`pkg::var = expr` LALR conflict** is documented as deferred in
  CHANGES.md §12. Don't reopen it.

## Start here

1. Read `MEMORY.md` (top section) and `FALLBACKS.md` "Known sv-tests Vacuous-PASS Paths".
2. Pick one row from the vacuous-PASS table (smallest scope first — `15.5.1 ->>` non-blocking event trigger is the most contained).
3. Build a focused reproducer in `iverilog/ivtest/ivltests/` (matching the surrounding naming convention), confirm the warning fires, then trace from `vvp.tgt sorry:` / `compile-progress:` warning emission back to the upstream gap.
4. Wrap any heavy iverilog/vvp run in `/tmp/memlimit.sh 2048 90 -- <cmd>` to avoid the tmpfs-pressure → OOM-kill class of failures.
5. Use the advisor before committing to a multi-layer change.
