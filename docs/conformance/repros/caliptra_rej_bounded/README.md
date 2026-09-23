# Caliptra `rej_bounded` testbench race

The pinned Caliptra v2.1.2 / Adams Bridge v2.0.3 testbench checks
`vld_coeff_ctr == 256` in a different `posedge clk_tb` process from the
scoreboard that increments the counter. IEEE 1800-2017/2023 §4.7 does not
order those Active-region processes. The checker can miss the transition and
the scoreboard then reports a queue underflow.

[`rej_bounded_tb.patch`](rej_bounded_tb.patch) moves the threshold decision
into the scoreboard after its counter update. A zeroize-edge waiter ends the
pulse on the next clock. The output comparison, underflow check, queue pop,
and queue clear remain in place. The patch targets
`submodules/adams-bridge/src/rej_bounded/tb/rej_bounded_tb.sv` relative to a
Caliptra source root. Apply it only to a disposable copy; the pinned release
checkout remains pristine.

[`rej_bounded_tb.vf`](rej_bounded_tb.vf) lists the pinned v2.0.3 unit sources;
set `ADAMSBRIDGE_ROOT` to the isolated source copy before compiling. Copy
[`input_seeds.first100.txt`](input_seeds.first100.txt) to each run directory as
`input_seeds.txt` and place the upstream `rej_bounded.py` there. The testbench
calls `python`, which must resolve to Python 3. It appends seeds, so use a
fresh run directory for each comparison. Current
Adams Bridge `main` has a different source manifest: use its own
`src/rej_bounded/config/rej_bounded_tb.vf` plus
`-I "$ADAMSBRIDGE_ROOT/src/abr_prim/rtl"`.

[`rej_bounded_race_probe.sv`](rej_bounded_race_probe.sv) reproduces the
same-edge dependency without the full DUT. Compile its original variant with
and without `-DREVERSE`: Icarus 13.0 devel and Verilator 5.050 produced
opposite pass/fail outcomes when the process declarations were reordered.
Adding `-DFIXED` gives zero errors in both orders under both simulators. The
probe is a scheduling reducer, not a full application regression.

The [revision-scoped evidence](../../session_logs/2026-09-23_caliptra_rej_bounded_race_fix.json)
records source/binary hashes and paired runs on both the pinned release and
current Adams Bridge `main`. The correction is proposed in [upstream PR 303](https://github.com/chipsalliance/adams-bridge/pull/303). These are
patched-testbench results, not a passing result for the unmodified release or
full Caliptra DV suite.
