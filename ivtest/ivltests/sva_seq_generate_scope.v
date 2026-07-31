// A named sequence or property is scoped to the GENERATE BLOCK that
// declares it, not to the module (IEEE 1800-2017 27.3/27.6: a generate
// block is a hierarchical scope; 27.5: a conditional generate
// instantiates at most ONE alternative).
//
// Declaring the same name in both arms was rejected:
//
//   error: duplicate sequence declaration `S1'.
//
// even though the arms are disjoint scopes. OpenTitan's
// prim_alert_sender writes exactly this for PingSigInt_S and
// AckSigInt_S across gen_async_assert / gen_sync_assert.
//
// The DECLARATION half is only half the defect. With lookup still keyed
// by name alone, the assertions in one arm would splice the OTHER arm's
// body -- a silent wrong result. So this test does not merely check
// that the file compiles: the two arms are given DIFFERENT bodies and
// the test proves each arm binds its own.
//
// x is driven high for exactly ONE cycle:
//   ga's S1 is `x [*2]'  -> must NOT match
//   gb's S1 is `x'       -> must match
// A fix that let both arms compile but spliced one body into both would
// give two hits or zero, never one from gb alone.
module sva_seq_generate_scope;

  logic clk = 0, x = 0, y = 0;
  int hits_async = 0, hits_sync = 0, errors = 0;

  always #5 clk = ~clk;

  sub #(.ASYNC(1)) u_a (.clk(clk), .x(x), .y(y));
  sub #(.ASYNC(0)) u_s (.clk(clk), .x(x), .y(y));

  initial begin
    repeat (2) @(posedge clk);
    x <= 1'b1; @(posedge clk); x <= 1'b0;   // high for exactly one cycle
    repeat (3) @(posedge clk);

    hits_async = u_a.ga.hits;
    hits_sync  = u_s.gb.hits;

    if (hits_async != 0) begin
      $display("FAIL: the ASYNC arm (S1 = x[*2]) matched %0d time(s) on a", hits_async);
      $display("      one-cycle pulse -- it spliced the other arm's body");
      errors = errors + 1;
    end
    if (hits_sync != 1) begin
      $display("FAIL: the SYNC arm (S1 = x) matched %0d time(s), expected 1", hits_sync);
      errors = errors + 1;
    end

    if (errors == 0) $display("PASSED");
    else $display("FAILED with %0d errors", errors);
    $finish;
  end

endmodule

module sub #(parameter bit ASYNC = 1) (input logic clk, x, y);
  if (ASYNC) begin : ga
    int hits = 0;
    sequence S1; x [*2]; endsequence
    A: assert property (@(posedge clk) S1 |=> y) else hits = hits + 1;
  end else begin : gb
    int hits = 0;
    sequence S1; x; endsequence
    A: assert property (@(posedge clk) S1 |=> y) else hits = hits + 1;
  end
endmodule
