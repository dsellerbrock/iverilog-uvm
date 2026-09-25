# OpenTitan CSRNG nested virtual-interface value

The pinned CSRNG `csrng_smoke_test` is **0/1 released DV** at the baseline:
its historical private VVP exits zero but reports a null nested VIF at 0 ps,
a TL-UL assertion, and `TEST FAILED CHECKS`. The two
`uvm_config_db#(virtual push_pull_if)::set` calls in `csrng_agent.build_phase`
have no object-value store for `cfg.vif.cmd_push_if` or
`cfg.vif.genbits_push_if`. This is separate from the released OTP result,
the UVM regression, and strict IEEE reducer outcomes. The pinned OpenTitan
checkout is `a78922f14a8cc20c7ee569f322a04626f2ac6127`; it is unedited.

The current `origin/main` baseline at `e8ba46282396f75ebfe878a3f87eb17db551c0ac`
was built privately in this CSRNG worktree. `ivl` SHA-256 is
`4e6f6e14ad9628c0e1c0f766db5ee1f21691d43d31f8d1a4033474fb2fc50a9c`;
VVP is `8539543ccbebf61dd942dd0714b2dc6da894106619e394e1b7f83b3ea80ca014`.
The paired strict `-g2017`/`-g2023` parent-VIF and direct-child controls
compile and run 4/4; the class-held nested-child legal case fails compile
2/2 with code generation `-3`. [baseline.json](baseline.json) gives exact
source and log hashes. A temporary copy-in probe returned `rv=0` for the
nested argument while design errors stayed at zero before and after
elaboration; [the trace](copy-in-trace.log) records it. That diagnostic
source edit was reverted before implementation.

IEEE 1800-2017 and 1800-2023 §§25.3 and 25.9 permit nested interface
instances and member access through a VIF bound to a particular instance;
§13.5.1 gives input-argument copy-in. The legal child-handoff expectation
combines those explicit rules: neither edition shows this exact class-held
spelling as a worked example. §25.9 requires fatal behavior for null parent
VIF dereference and retains interface/modport assignment compatibility.
Local primary copies are `reference-standards/local/IEEE_Std_1800-2017.pdf`
(SHA-256 `12e3dc7bafafca28af2b89ebc2761fb7a606d68716cf04c2d93c8617c78eebec`)
and `reference-standards/local/IEEE_Std_1800-2023.pdf`
(SHA-256 `2280eb7f39532ca990b9bbd2e4226ae5c89910b51f42b2eb0e972df4403c9597`).

The final private `ivl` SHA-256 is
`a2470636e85fced3aacc6df62f790e32615e339f8dca012f18191d60eaa708bd`;
VVP remains `8539543ccbebf61dd942dd0714b2dc6da894106619e394e1b7f83b3ea80ca014`.
The fix pairs each type-compatible physical parent with its own nested child,
evaluates the class-held receiver once, and passes the selected child's exact
instance handle to a VIF formal. A declared child with no physical parent
compiles and fails at runtime on null dereference. Missing or wrong-type
children and an unexported parent modport reject at compile time. Paired
strict 2017/2023 focus passes 14/14 in both legacy and JSON harnesses;
neighboring VIF cases pass 184/184 in each. The no-instance child-array or
parameterized-child value path remains explicitly unsupported because no
concrete instance is available to resolve its specialization.
[Final focused legacy](focus-legacy-candidate4.log),
[final focused JSON](focus-json-candidate4.log),
[neighboring legacy](neighbor-legacy-candidate4.log), and
[neighboring JSON](neighbor-json-candidate4.log) logs record those counts;
the earlier `focus-*-final.log` files predate the last two added reducers.
[The pinned VVP excerpt](bytecode-handoff-excerpt.txt) shows runtime parent
selection followed by the corresponding physical child handle and object
store before both CSRNG config-db set calls.

The pinned CSRNG replay uses the historical disposable BlkLen overlay and
`-g2017 -gcommercial-unsafe`, so it is a nonstandard compatibility result,
separate from those strict IEEE reducers. With the final private tool it
compiles to a 70,150,010-byte VVP image in 3.1 seconds, then loads the native
AES DPI bundle and runs to 1,000 ps. It is still **0/1 released DV**: a
successful CSR backdoor read returns an unknown field value at
`csr_utils_pkg.sv:412`, causing `UVM_ERROR`, `TEST FAILED CHECKS`, a follow-on
TL-UL end-of-simulation assertion, and exit 1. There is no intended pass
marker, meaningful CSRNG command traffic, or scoreboard comparison. The
earlier null nested-VIF failure at 0 ps is absent. The exact CSR path and
cause of its unknown value are not logged, so that is a separate investigation
for a later PR. The compile also retains a skipped `mon_cb` monitor event, an
assumed-false monitor condition, and an ignored `int_state_read_enable_c`
constraint item. Those prevent claiming complete DV checks even if a later
runtime reaches a pass banner. See
[compile profile](release-compile-candidate4.json),
[compile warnings](release-compile-candidate4.stderr.log),
[native DPI build](release-dpi-build-candidate4.json),
[runtime profile](release-runtime-candidate4.json), and
[runtime log](release-runtime-candidate4.stdout.log).

The named disposable overlay is the only application patch; the pinned
OpenTitan checkout and shared Caliptra tool remain unchanged. The final
private tool passes the [broad legacy gate](broad-legacy-final.log): 6,601
total, 6,596 passed, zero failed, two not implemented, three expected
failures, VPI 131/131, negatives 155/155, and runtime invariants 15/15.
[Full JSON](full-json-final.log) passes 3,640/3,640, and
[real-DPI UVM](real-dpi-uvm-final.log) passes 358/358 with zero failed or
skipped. These compiler/UVM results do not change the 0/1 released CSRNG DV
verdict.
