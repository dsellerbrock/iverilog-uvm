# OpenTitan CSRNG owner-held inline randomize receiver

PR: https://github.com/dsellerbrock/iverilog-uvm/pull/366

This worktree starts at PR #365 (`c111320aa`). The pinned OpenTitan checkout
remains clean at `a78922f14a8cc20c7ee569f322a04626f2ac6127`. Its existing
CSRNG BlkLen patch is applied only in the disposable FuseSoC source copy;
that copied `tb.sv` retains SHA-256
`4e8ac42c67dbf7927538819a8447c2db670cbc08adff8b7eb35c131f0376fd93`.
The exact profile has `-g2017 -gcommercial-unsafe`, the selected UVM 1.2
source, native AES DPI, and the released `csrng_smoke_test` sequence.

The first released command item used `cs_item.randomize() with { cs_item.clen
== 12; ... }`. The previous compiler treated `cs_item.clen` as a captured
caller value and returned zero before command traffic. Class-property lookup
represents that receiver as `@.cs_item`; expression-side receiver-root
extraction accepted only a one-component path and lost the target identity.
The fix recognizes only an unindexed implicit-this property receiver, while
giving a same-named property in the randomized class precedence. An absent
member under the direct receiver spelling now produces a compile error rather
than a captured value.

Registered strict IEEE 1800-2017 and 2023 legal and invalid-member reducers
were RED 0/4 in each focused legacy and JSON runner against PR #365. The final
private compiler passes 4/4 in each runner; neighboring randomize-context
tests pass 11/11 in each runner, and `make check` passes. The legal reducer
also covers raw statement position, distinct caller state, explicit local
qualification, failed-solve rollback, and target-class member shadowing.
The full legacy gate passes with 6,617 total, zero failed, two not implemented,
and three expected failures. The full JSON gate ran 3,656 tests with zero
failures; the `-g2012` real-DPI UVM umbrella passed 358/358 with zero skipped.
The complete [legacy](broad_legacy.log.gz) and [JSON](broad_json.log.gz)
logs are compressed in this directory.
The final private SHA-256 values are `iverilog`
`b93f73000e75159c4064a487d4137aac2624c617cbdbc19ee845a4e95fe0f957`,
`ivl` `5a9cc2b3f3fe5912640f508e2d72e4206fb4362993f255f1fe01675e23da398d`,
and VVP `fbd1a91179518a3e56f9b20832058b27abdc813744f383d9ff093225c1e1b757`.

The named-overlay pinned CSRNG compile and native AES DPI build exit zero on
that private image. VVP reaches 16,454,635 ps and exits zero after an
`AesSecCmDataRegKeySca` UVM_ERROR in `aes_cipher_core.sv:827`, one assertion
error, and `TEST FAILED CHECKS`; there is no intended pass. The separate
`int_state_read_enable_c` ignored-constraint warning remains. This is **0/1
released nonstandard OpenTitan DV**, not an IEEE or UVM regression pass. The
prior first inline randomize fatal is absent and runtime advances. A separate
`UVM_MEDIUM` replay shows the scoreboard processing one SW-app instantiate
command at 15,371,293 ps before the AES assertion, but no completed generate
or genbits comparison. [Exact commands](release_commands.json),
[low-verbosity runtime](release-runtime.stdout.log.gz), and
[medium-verbosity runtime](release-runtime-medium.stdout.log.gz) preserve the
source-copy hashes, commands, exits, and output.

This patch claims only the stable direct receiver spelling. The paired
same-object alias reducer still fails in both strict editions, and an explicit
`this` target lookup can fall through to a caller member. They are recorded as
DD-059 and DD-060 with [sources and logs](boundary_results.json), outside this
PR. No Caliptra job, Verilator run, GPU experiment, or CI poll was performed.
