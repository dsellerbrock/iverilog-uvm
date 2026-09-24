# No-candidate virtual-interface call and an unrelated unsafe waiver

The installed compiler rejects `no_candidate_unrelated` in both 2017 and 2023
`-gcommercial-unsafe` modes. Its only concrete interface is `b`; the call is
through `virtual no_candidate_a_if`, and there is no physical instance of that
type. The call cannot enter `b.drive`, so `b`'s task write is proven unused.
Strict mode still rejects its mixed driver. A same-type physical candidate
must still reject in unsafe mode.

The narrow candidate removes the global unknown-call mark only when
`elaborate_dynamic_interface_method_call_` found no physical method candidate.
That path already emits a receiver-only runtime-fatal call and cannot enter a
task body. Other unresolved-call tracking is unchanged. The permanent paired
fixture is `ivtest/ivltests/sv_interface_task_no_candidate_waiver.v`.

`result.json` records twelve installed-versus-private compile/runtime rows,
commands, diagnostics, and compiler/runtime hashes. The installed compiler is
RED only for the two unrelated unsafe rows. The private candidate is GREEN in
both editions: the unrelated unsafe case compiles and prints `PASSED`; strict
unrelated and unsafe same-type cases retain their exact mixed-driver errors.
The private candidate also passed the focused JSON suites: interface-driver
40/40, virtual-override 24/24, and interface-port 28/28. The first attempt to
run the latter two suites concurrently in one temporary `ivtest/work` directory
collided and each showed one runtime error; both passed when rerun sequentially.

The private compiler replayed the pinned strict top compile with exactly 46
mixed-driver errors and no other errors; all 71 diagnostic lines match the
installed compiler. On the completed `smoke_test_veer` disposable-source
profile, explicit unsafe compilation succeeds and all 28 diagnostic lines
match the installed compiler. `private_strict_top_compile.json` and
`private_top_compile.json` record commands, copied-input fingerprints where
applicable, and the private compiler hash. Neither compile is an L0 runtime.

The corrected private JSON gate passes 3,542/3,542 with zero failures. The
initial private legacy run started with an incomplete temporary install and
had ten setup-only failures from missing `null`/`stub` targets, UVM files,
and a relative SVA include. These assets were linked read-only from the
shared installation/source tree. The full private legacy rerun then passed:
6,550 ordinary passes of 6,555 total, zero failures, two not implemented,
and three expected failures. `gate_summary.json` records the full-log hashes,
commands, exit codes, and totals; the raw logs remain in the campaign checkout.

The installed compiler and VVP remain unchanged while the long Caliptra L0
runs use them. Shared installation and application runtime replay for this
candidate remain pending. The active L0 results qualify the older installed
compiler, not this candidate.
