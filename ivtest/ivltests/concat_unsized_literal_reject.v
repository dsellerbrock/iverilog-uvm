// IEEE 1800-2017 11.4.12.1: unsized constant numbers shall not be
// allowed in concatenations. A bare unsized literal operand must
// still be rejected even though unsized *expressions* are accepted.
module main;
  logic [32:0] y;
  initial begin
    y = {1'b0, 5};
    $display("FAILED");
  end
endmodule
