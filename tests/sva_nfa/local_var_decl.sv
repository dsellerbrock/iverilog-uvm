// IEEE 1800-2017 16.10: a named sequence may declare local variables
// between its header semicolon and sequence expression. This uses the exact
// package-qualified packed-width shape found in OpenTitan's tlul_assert.sv.
// NFA-EXPECT-FALLBACK
package local_var_decl_pkg;
  parameter int W = 8;
endpackage

module local_var_decl;
  logic clk = 0, a = 0, b = 0;
  logic [local_var_decl_pkg::W-1:0] d = 0, c = 0;
  always #5 clk = ~clk;

  sequence captured_match;
    bit [local_var_decl_pkg::W-1:0] captured;
    (a, captured = d) ##1 (b && c == captured);
  endsequence

  cv: cover property (@(posedge clk) captured_match);

  initial begin
    @(negedge clk) a = 1; d = 8'h5a;
    @(negedge clk) a = 0; b = 1; c = 8'h5a;
    @(negedge clk) b = 0; c = 0;
    @(negedge clk);
    $display("local_var_decl cover=%0d (expect 1)", _ivl_sva0_cnt0);
    $finish(0);
  end
endmodule
