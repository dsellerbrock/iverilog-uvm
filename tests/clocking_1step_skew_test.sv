// Regression: the `1step` time-step literal (IEEE 1800 §14.4) used in a
// clocking-block default skew, e.g.
//   clocking cb @(posedge clk);
//     default input #1step output #2;
//   endclocking
// (pervasive in OpenTitan *_dv_if.sv interfaces). `1step` did not lex as a
// delay value (it tokenized as `1` then identifier `step`), so the clocking
// item failed to parse and desynced the enclosing interface. `1step` now lexes
// to a token accepted as a delay_value; clocking skew timing is not modeled, so
// it is treated as a placeholder.
interface dv_if(input clk);
  logic [5:0] state;
  bit         got_state;
  clocking cb @(posedge clk);
    default input #1step output #2;
  endclocking
endinterface
module top;
  logic clk = 0;
  dv_if u(clk);
  initial $display("PASS");
endmodule
