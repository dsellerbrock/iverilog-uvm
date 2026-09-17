// A property/sequence body that starts with two consecutive, un-
// parenthesized leading cycle delays (`##N ##M seq`, nothing between
// them) must parse and must compose the delays exactly like a single
// combined delay (`##(N+M) seq`). Confirmed independently: slang
// (--std 1800-2017) accepts `##3 ##0 b;` with 0 errors.
//
// Root cause: in parse.y, `sva_seq_expr`'s leading-cycle-delay
// productions (`K_CYCLE_DELAY sva_cycle_delay_value sva_seq_atom` and
// its bounded/unbounded-window/`[*]`/`[+]` siblings) all required a
// trailing `sva_seq_atom`. A second, unparenthesized `K_CYCLE_DELAY
// ...` only reduces to `sva_seq_expr` -- there was no `sva_seq_atom`
// alternative starting with `K_CYCLE_DELAY` -- so it could not fill
// that trailing slot and the parser raised a raw `syntax error`.
// Adding parens around the second delay (`##3 (##0 b)`) already
// worked, since `'(' sva_seq_expr ')'` is itself an `sva_seq_atom`
// alternative; that discrepancy (parenthesized works, unparenthesized
// doesn't) is what exposed the gap.
//
// Found via real, unmodified Caliptra formal-verification source
// (src/ecc/formal/properties/fv_montmultiplier_glue.sv uses
// `##DLY_CONCAT ... ##0 (1'b1, fv_result = reduction_prime(...))`,
// a parameter-valued leading delay immediately followed by another
// leading delay). See DISCOVERED_DEBT.md DD-039.
//
// Fix: a new `sva_seq_lead_delay` nonterminal lets a leading delay's
// trailing operand be either a plain atom (base case) or another
// leading delay, so consecutive delay prefixes now chain without
// parens -- mirroring IEEE 1800-2017/2023's right-recursive
// `sequence_expr ::= cycle_delay_range sequence_expr | ...`.
// Deliberately scoped to just the delay-prefix productions (not the
// full `sva_seq_expr`) to avoid pulling `until`/`implies`/`iff`/
// `within`/the concat form into a leading delay's decision point.
module main;
  bit clk = 0;
  bit a = 0, b = 0;
  int fails = 0;

  always #5 clk = ~clk;

  // Chained delays: ##2 ##3 must behave exactly like ##5.
  property p_chain;
    a |=> ##2 ##3 b;
  endproperty
  ap_chain: assert property (@(posedge clk) p_chain) else fails++;

  property p_ref;
    a |=> ##5 b;
  endproperty
  ap_ref: assert property (@(posedge clk) p_ref) else fails++;

  initial begin
    @(posedge clk); #1;
    a = 1;
    @(posedge clk); #1;
    a = 0;
    repeat (5) begin
      @(posedge clk); #1;
    end
    b = 1;
    @(posedge clk); #1;
    b = 0;
    repeat (2) begin
      @(posedge clk); #1;
    end
    if (fails != 0) begin
      $display("FAILED, fails=%0d", fails);
      $finish;
    end
    $display("PASSED");
    $finish;
  end
endmodule
