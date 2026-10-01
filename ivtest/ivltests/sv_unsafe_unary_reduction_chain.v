// `!&{a, b}': IEEE 1800-2017/2023 A.8.3 applies a unary operator only to a
// primary. Commercial tools accept a reduction operand anyway (OpenTitan
// keymgr scoreboard), so Icarus accepts the chain only under
// -gcommercial-unsafe; sv_unary_reduction_chain_fail keeps strict mode.
module test;
  logic a = 1, b = 1, c = 0;
  logic [3:0] v = 4'b1010;
  initial begin
    if ((!&{a, b}) === 1'b0 && (!&{a, c}) === 1'b1 && (!|v) === 1'b0
        && (!^v) === 1'b1 && (!|{c, c}) === 1'b1)
      $display("PASSED");
    else
      $display("FAILED");
  end
endmodule
