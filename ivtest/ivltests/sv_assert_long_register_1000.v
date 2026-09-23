// IEEE 1800-2017/2023 16.7: finite ##1 sequence concatenation.
// The generated antecedent sample must not alias step index 999.
`define LONG_1 keep
`define LONG_2 `LONG_1 ##1 `LONG_1
`define LONG_4 `LONG_2 ##1 `LONG_2
`define LONG_8 `LONG_4 ##1 `LONG_4
`define LONG_16 `LONG_8 ##1 `LONG_8
`define LONG_32 `LONG_16 ##1 `LONG_16
`define LONG_64 `LONG_32 ##1 `LONG_32
`define LONG_128 `LONG_64 ##1 `LONG_64
`define LONG_256 `LONG_128 ##1 `LONG_128
`define LONG_512 `LONG_256 ##1 `LONG_256

module long_sequence_checker_1000(input logic clk, start, keep);
  integer passes = 0, fails = 0;
  check: assert property (@(posedge clk) start |->
      `LONG_512
      ##1 `LONG_256
      ##1 `LONG_128
      ##1 `LONG_64
      ##1 `LONG_32
      ##1 `LONG_8
  ) passes++; else fails++;
endmodule

module sv_assert_long_register_1000;
  logic clk = 0, start = 1, good_keep = 1;
  logic bad_keep = 1;
  long_sequence_checker_1000 good(clk, start, good_keep);
  long_sequence_checker_1000 bad(clk, start, bad_keep);
  initial begin
    for (integer i = 0; i < 1000; i++) begin
      if (i == 999) bad_keep = 0;
      #5 clk = 1;
      #1 clk = 0;
      if (i == 0) start = 0;
    end
    #1;
    if (good.passes != 1000 || good.fails != 0 || bad.passes != 999 || bad.fails != 1)
      $fatal(1, "long 1000 good=%0d/%0d bad=%0d/%0d", good.passes, good.fails, bad.passes, bad.fails);
    $display("PASSED");
    $finish(0);
  end
endmodule
