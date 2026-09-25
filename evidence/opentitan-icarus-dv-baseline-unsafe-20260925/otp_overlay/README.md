# OTP named compatibility replay

The released `otp_ctrl_smoke_vseq` completes **1/1 named OpenTitan DV** on the
2026-09-25 private Icarus image under `-gcommercial-unsafe` and the pinned OTP
RAM-path source overlay. This is a nonstandard compatibility result, separate
from the 84-row unmodified-source matrix and IEEE conformance. OpenTitan stayed
at `a78922f14a8cc20c7ee569f322a04626f2ac6127`; its source checkout and
the FuseSoC-generated original files were not edited.

The generated and pinned `tb.sv` files both hash to
`9ae010405678fbaad44c83143793345af6e5aa1e0152bd2e06a9c838f3d63f1a`.
The [hash-checked overlay helper](../../../docs/conformance/release_overlays/opentitan/otp_mem_path_overlay.py)
created this directory's [disposable `tb.sv`](tb.sv), SHA-256
`a7bd1964e2c7e626d5a25a04597129417a7c47f89c95069da6af86dd094689c6`.
Only its two OTP memory-path macro lines changed. The [cloned source list](source-list.scr)
substitutes that copy for the original at line 311; the [cloned outer command
file](matrix-iverilog.scr) keeps the `+timescale+1ns/1ps` setting. The matrix's
top modules, UVM defines, and selected test/sequence were preserved. UVM log
verbosity was raised from LOW to HIGH solely to expose checked TL traffic.

The exact [compile command and tool/input hashes](compile.command.json),
[native DPI build commands and source hashes](dpi.command.json), and
[runtime command and hashes](runtime.command.json) are recorded. The installed
`ivl` SHA-256 was
`20df9f85fbea3da012ffe67b0dff167323a87c20d68f561914d69ceb34c06223`;
the installed VVP runtime SHA-256 was
`21ced9054cdb7409534fc73509bf91b0a04d6614736c0a1adb7abd04bb6e49a5`.
The compiled VVP and freshly built native DPI library stayed under
`/private/tmp/ot-dv-baseline-unsafe-20260925/otp-overlay-20260925/`.

Compilation exited zero in 5.979 seconds. VVP exited zero in 258.296 seconds
at 141094616 ps with one `TEST PASSED CHECKS`, zero fail/assertion lines,
UVM WARNING/ERROR/FATAL **0/0/0**, 1343 scoreboard-observed TL A and 1343 TL D
items after the test-sequence start, and a DAI access to address `0x66c` in
partition 4. See the [qualification result](result.json), [compile diagnostics](compile.stderr.log),
and [compressed runtime log](runtime.stdout.log.gz).

The compile retained all six OTP bin groups and 36 constructor method
endpoints with no dropped bins or ignored constraint items. It emitted 36
explicit nonstandard purity warnings, 40 preexisting procedural force-RHS
`sorry` diagnostics, and 36 preexisting `uwire` multiple-driver compile-progress
warnings. This seed does not prove a functional coverage bin hit. All ten
logged partition injection selectors were `read=0, write=0`, so the warned
force branches were unexercised. These limitations remain visible in
[result.json](result.json); this replay does not qualify other seeds or the
full released OpenTitan suite.
