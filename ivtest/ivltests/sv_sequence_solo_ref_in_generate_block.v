// A named sequence declared inside a conditional generate block, used as
// the ENTIRE property expression of a cover/assert statement in the same
// block, must resolve correctly. Confirmed independently: slang
// (--std 1800-2017) accepts this, 0 errors.
//
// Real, unmodified OpenTitan RTL relies on exactly this shape
// (hw/ip/tlul/rtl/tlul_assert.sv: a `sequence ..._S; ... endsequence`
// declared inside `if (EndpointType == "Host") begin : gen_host_cov`,
// used by a `cover property (@(...) disable iff (...) (SEQ))` in the
// same block via the TLUL_D_CHAN_CONTENT_CHANGED_WO_ACCEPTED/TLUL_COVER
// macros) -- this was the single remaining blocker (after L125) for
// every top_*_xbar_*_sim core across all three OpenTitan tops.
//
// Root cause: a regression in this session's own L121 fix (named
// property forward-reference deferral). The deferral guard checked
// whether an unresolved bare name was already a known SIGNAL before
// deferring it as a possible forward-referenced property, but not
// whether it was already a known SEQUENCE. A sequence reference used
// alone as a property expression is never going to appear in the
// properties map at all, so it always looked exactly like an
// unresolved-property shape and got deferred to end-of-module -- where
// pform_cur_generate no longer matches the generate block the sequence
// was actually declared in. This "worked" by accident at plain module
// scope (both the deferred retry's implicit scope and a module-scope
// declaration's key are null) and only broke inside a generate block.
module main;
  bit clk = 0, rst_n = 1;
  bit a = 0, b = 0;
  int fails = 0;

  always #5 clk = ~clk;

  if (1) begin : gen_scope
    sequence changed_s;
      a ##1 b;
    endsequence
    // Cover -- the exact real-world shape (TLUL_COVER expands to this).
    cp_solo: cover property (@(posedge clk) disable iff (!rst_n) changed_s);
    // Assert (implication form, unambiguous pass/fail semantics) over
    // the same solo named-sequence reference, for a functional check.
    ap_solo: assert property (@(posedge clk) disable iff (!rst_n)
                               a |-> changed_s) else fails++;
  end

  initial begin
    @(posedge clk); #1;
    a = 1;
    @(posedge clk); #1;
    a = 0;
    b = 1;
    @(posedge clk); #1;
    b = 0;
    @(posedge clk); #1;
    if (fails != 0) begin
      $display("FAILED, fails=%0d", fails);
      $finish;
    end
    $display("PASSED");
    $finish;
  end
endmodule
