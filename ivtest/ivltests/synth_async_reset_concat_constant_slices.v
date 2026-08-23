`begin_keywords "1800-2012"

module synth_async_reset_concat_constant_slices;
  logic clk;
  logic reset;
  logic [8:0] data;
  logic [2:0] upper;
  logic [4:0] middle;
  logic lower;

  // Synthesis shares the complete r-value for this concatenated l-value, then
  // projects the three leaves with fixed selects at canonical bases 0, 1, and
  // 6. The unequal widths and asymmetric bit patterns catch both a wrong base
  // and a reversed slice while the reset branch proves the selects constant.
  always_ff @(posedge clk or posedge reset)
    if (reset)
      {upper, middle, lower} <= 9'b101_01101_0;
    else
      {upper, middle, lower} <= data;

  (* ivl_synthesis_off *)
  initial begin
    clk = 1'b0;
    reset = 1'b0;
    data = 9'b010_10011_1;

    #1 reset = 1'b1;
    #1;
    if ({upper, middle, lower} !== 9'b101_01101_0)
      $fatal(1, "asymmetric concatenated reset failed: %b_%b_%b",
             upper, middle, lower);

    reset = 1'b0;
    #1 clk = 1'b1;
    #1 clk = 1'b0;
    if ({upper, middle, lower} !== 9'b010_10011_1)
      $fatal(1, "concatenated data update failed: %b_%b_%b",
             upper, middle, lower);

    $display("PASSED");
  end
endmodule

`end_keywords
