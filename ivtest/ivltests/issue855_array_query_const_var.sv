// IEEE 1800-2017/2023 20.7: an array query on a fixed-size variable is a
// constant expression, including a dimension that lands on the packed
// dimensions after the unpacked ones (the standard's $size(Ram, 2) == 16).
module issue855_array_query_const_var;
  typedef logic [16:1] Word;
  Word Ram[0:9];
  logic [3:0][7:0] mem [2][5:1];

  localparam int SR = $size(Ram, 2);
  localparam int S1 = $size(Ram, 1);
  localparam int H2 = $high(Ram, 2);
  localparam int L2 = $low(Ram, 2);
  localparam int LF2 = $left(Ram, 2);
  localparam int I2 = $increment(Ram, 2);
  localparam int MS3 = $size(mem, 3);
  localparam int ML4 = $left(mem, 4);
  localparam int MU = $unpacked_dimensions(mem);

  logic [SR-1:0] word_wide;

  bit ok = 1;

  task automatic check(string what, int got, int want);
    if (got !== want) begin
      $display("FAILED: %s = %0d, expected %0d", what, got, want);
      ok = 0;
    end
  endtask

  initial begin
    check("$size(Ram,2)", SR, 16);
    check("$size(Ram,1)", S1, 10);
    check("$high(Ram,2)", H2, 16);
    check("$low(Ram,2)", L2, 1);
    check("$left(Ram,2)", LF2, 16);
    check("$increment(Ram,2)", I2, 1);
    check("$size(mem,3)", MS3, 4);
    check("$left(mem,4)", ML4, 7);
    check("$unpacked_dimensions(mem)", MU, 2);
    check("declared width", $bits(word_wide), 16);
    // The same queries outside a constant context.
    check("run-time $size(Ram,2)", $size(Ram, 2), 16);
    check("run-time $right(Ram,2)", $right(Ram, 2), 1);
    check("run-time $size(mem,4)", $size(mem, 4), 8);
    if (ok) $display("PASSED");
  end
endmodule
