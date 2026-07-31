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


## duplicate sequence declaration: REDUCED

CORRECTION. An earlier revision of this file said five hand-written
reconstructions all passed and no minimal test existed. That was wrong.
The test loop used to check them swallowed the diagnostic, so real
failures were recorded as ACCEPTED. Re-run directly, the small case
fails exactly as the real file does. There was never a mystery here.

Minimal reproducer (8 lines), `sva_seq_generate_scope.sv`:

    module top;
      logic clk=0, p=0, n=0;
      if (1) begin : ga
        sequence S1; p == n [*2]; endsequence
      end else begin : gb
        sequence S1; p == n; endsequence
      end
    endmodule

    error: duplicate sequence declaration `S1'.

Each generate block is its own scope, so declaring `S1` in both arms of
a conditional generate is legal -- and only one arm is ever elaborated.
OpenTitan's prim_alert_sender does exactly this with `PingSigInt_S` and
`AckSigInt_S` across `gen_async_assert` / `gen_sync_assert`.

Root: `pform_sva_declare_sequence` (pform.cc:5069) registers into
`sva_module_sequences`, a map keyed by NAME alone, and rejects any
repeat. The map is cleared only at endmodule
(`pform_sva_module_done`). Generate scope is not part of the key. The
same holds for `sva_module_properties`, `sva_param_sequences` and
`sva_param_properties`.

Control that must keep failing: the same two declarations at MODULE
level, with no generate, are a genuine duplicate and are correctly
rejected today. A scope-aware key has to keep rejecting that.

## Separately: an undefined sequence reference is silently inert

Reduced from the same investigation, and worse than the above --
`sva_undefined_sequence_silent.sv`:

    A: assert property (@(posedge clk) NoSuchSeq_S |=> 1'b0);

`NoSuchSeq_S` is never declared. This compiles with a
"compile-progress: unresolved reference" WARNING, and the assertion
then never fires -- `X |=> 1'b0` cannot hold under any trace, so a live
assertion would report on every clock. It reports nothing.

For a verification flow that is the dangerous shape: the testbench
builds, the run is green, and a check the engineer believes exists does
not. Unlike a mistyped signal there is no later symptom.
