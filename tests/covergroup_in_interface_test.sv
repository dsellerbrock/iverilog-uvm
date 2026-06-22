// Regression: covergroups as interface/module items (parse-and-ignore no-op).
//
// OpenTitan DV binds functional-coverage interfaces into the DUT, e.g.
// pattgen_cov_if / i2c's cov interfaces, which declare `covergroup cg
// @(posedge clk); ... endgroup` at interface scope. iverilog rejected these
// with "Invalid module item" because covergroups were only allowed as class
// items. Functional coverage is a no-op in this flow, so the parser now accepts
// covergroups at module/interface scope (clocked, ported, or with-function-
// sample forms) and discards them, letting the rest of the interface compile.
interface cov_if (input logic clk_i, input logic [3:0] sig);

  // clocking-event covergroup with coverpoints + cross + bins
  covergroup ctrl_cg @(posedge clk_i);
    option.name = "ctrl_cg";
    cp_a: coverpoint sig[0];
    cp_b: coverpoint sig[1];
    cp_v: coverpoint sig {
      bins lo   = {0};
      bins mid[4] = {[1:14]};
      bins hi   = {15};
    }
    cross_ab: cross cp_a, cp_b;
  endgroup

  // bare (unclocked) covergroup
  covergroup misc_cg;
    cp_x: coverpoint sig[2];
  endgroup

endinterface

module top;
  logic clk = 0;
  logic [3:0] s = 0;
  cov_if u_cov (.clk_i(clk), .sig(s));
  initial begin
    #1 s = 4'hA; #1 clk = 1; #1 clk = 0;
    $display("PASS");
  end
endmodule
