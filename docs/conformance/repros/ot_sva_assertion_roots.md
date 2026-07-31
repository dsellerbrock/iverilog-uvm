# OpenTitan assertions: measured state

`-DSYNTHESIS` disables OpenTitan's assertions entirely (prim_assert.sv
selects `prim_assert_dummy_macros.svh` for it). Every "OpenTitan clean"
figure elsewhere in this directory is an assertions-OFF measurement of
the RTL. This file measures with assertions ON.

## Counts

Compiled as `iverilog -g2012 -s<ip> -c <ip>.scr` (no `-DSYNTHESIS`),
`lowrisc:prim_generic:all:0.1` mapping:

    ip            before   after `default disable iff`
    spi_device      11        10
    aes              8         7
    hmac             8         7
    otbn            46        45
    kmac             8         7
    TOTAL           81        76

## The error counts are mostly CASCADE

A failure at module-item level stops the parser recovering for the rest
of the module, so one bad construct produces one error per remaining
assertion in the file. In otbn's 46, the distinct roots were four:

| preprocessed line | construct | status |
|---|---|---|
| 42555 | `default disable iff` without parentheses | FIXED |
| 41269, 41272 | duplicate sequence declaration (`PingSigInt_S`, `AckSigInt_S`) | root found in code, not reduced |
| 46033, 46047 | `prim_sync_reqack` reset checks | open, NOT reduced |
| 89599 | `within` with `##[0:$]` operands | open |

Everything else in the list was a follow-on error at the tail of an
`ASSERT_ERROR` action block -- `"SomeName_A");` -- which is the parser
resynchronizing, not a distinct defect.

## What `default disable iff` cost

One root, one line of grammar, five errors across the corpus -- but the
five were spread over five different IPs, because tlul_assert.sv is
instantiated everywhere. Cascade means error counts are a poor proxy for
work remaining; root counts are the useful measure.

## prim_sync_reqack: reduced, but NOT to a minimal reproducer

The two `SyncReqAckRstSrc` / `SyncReqAckRstDst` assertions fail with
"Error in property_spec of concurrent assertion item" in the real file:

    assert property (@(posedge clk_src_i) disable iff ((0) !== '0)
      ($fell(rst_src_ni) |-> (!src_reset_flag throughout !dst_reset_flag[->1])))

Cutting the enclosing module down to its header plus that one generate
block (57 lines) still fails. But every hand-written reconstruction of
that shape PASSES -- including the generate block with its local
`logic` declarations and `always_ff` blocks, the untyped port style, the
parenthesized `disable iff ((0) !== '0)`, the multi-line `$error` with
`%m`, `throughout` with a goto-repetition right operand, and all of
those combined.

Delta-debugging by line deletion is not sound here: it does not respect
`begin`/`end` nesting, so it converges on files that fail for an
unrelated syntax reason. A structure-aware reduction, or dumping the
parser state at the failure, is the next step -- not another guess at
the shape.

Recording this rather than leaving it implied: the construct is
identified and the failing file is down to 57 lines, but the trigger is
NOT yet isolated, and the four hand-built reproductions that pass are
evidence against the obvious hypotheses.


## duplicate sequence declaration: root located, reproducer NOT reduced

`prim_alert_sender` declares `PingSigInt_S` and `AckSigInt_S` in BOTH
arms of a conditional generate:

    if (AsyncOn) begin : gen_async_assert
      sequence PingSigInt_S; ... endsequence
      sequence AckSigInt_S;  ... endsequence
      ...
    end else begin : gen_sync_assert
      sequence PingSigInt_S; ... endsequence
      sequence AckSigInt_S;  ... endsequence
      ...
    end

Each generate block is its own scope, so this is legal.

The root is visible in the code: `pform_sva_declare_sequence`
(pform.cc:5069) registers into `sva_module_sequences`, a map keyed by
NAME alone with no scope component, and rejects any repeat. The same is
true of `sva_module_properties`, `sva_param_sequences` and
`sva_param_properties`. Generate scope is not represented at all.

What is NOT yet established: a minimal test that discriminates. Every
hand-written reconstruction of the shape above is ACCEPTED -- including
two sequences per arm, the sequences used by assertions in each arm,
`[*2]` bodies, parameterized `##[N+2:N+3]` delays, and multiple
instantiations of the module. The failure reproduces only from the real
file, reduced so far to 541 lines (package + module, first arm's
assertions deleted).

Line-deletion reduction is unsound here in BOTH directions: it can drop
`begin`/`end` and produce a different syntax error, and -- as observed
-- it can drop the generate `if/else` itself, leaving four declarations
genuinely at module level, which is a real duplicate and keeps the
predicate satisfied while destroying the thing under test.

Two facts worth keeping separate:
  * assertions inside generate blocks DO elaborate and DO fire
    (verified: an always-false property inside `if (1) begin : g`
    reports at `top.g`), so nothing is being silently dropped;
  * the registration map has no scope key, which is a defect on its own
    terms whatever the exact trigger turns out to be.

Next step: a structure-aware reduction (delete balanced generate blocks
and whole declarations, never single lines), or instrument
pform_sva_declare_sequence to print the call site and compare the real
file against the passing reconstruction. Not another guess at the shape
-- five have now failed to reproduce it.
