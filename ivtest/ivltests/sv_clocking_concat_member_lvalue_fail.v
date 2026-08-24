// IEEE 1800-2017 14.3 forbids a clocking signal in a concatenation
// l-value. Keep the clocking member nested so the recursive preflight is
// exercised before ordinary l-value elaboration can alias it to raw.
interface clocking_concat_member_if(input logic clk);
  logic raw;

  clocking cb @(posedge clk);
    output raw;
  endclocking
endinterface

module sv_clocking_concat_member_lvalue_fail;
  logic clk;
  logic plain;
  clocking_concat_member_if bus(clk);

  initial {plain, {bus.cb.raw}} <= 2'b10;
endmodule
