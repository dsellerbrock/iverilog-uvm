module issue3207_packed_bit_local;
  bit clk = 0, start = 0;
  logic [7:0] data = 0, expected = 0;
  logic [7:0] unknown_data = 8'b10xz0101;
  always #5 clk = ~clk;

  sequence s;
    logic unused;
    bit [7:0] v, w;
    bit flag;
    (start, v = data, w = data, flag = 1) ##2
      (flag && v == expected && w == expected);
  endsequence
  sequence converted;
    bit [7:0] v = 8'b10xz0101;
    (start && v === 8'b10000101);
  endsequence
  sequence assigned;
    bit [7:0] v;
    (start, v = unknown_data) ##1 (v === 8'b10000101);
  endsequence
  cover property (@(posedge clk) s);
  cover property (@(posedge clk) converted);
  cover property (@(posedge clk) assigned);

  initial begin
    @(negedge clk) begin start = 1; data = 8'h96; end
    @(negedge clk) data = 8'h3c;
    @(negedge clk) begin start = 0; expected = 8'h96; end
    @(negedge clk) expected = 8'h3c;
    @(negedge clk);
    if (_ivl_sva0_cnt0 != 2 || _ivl_sva1_cnt0 != 2 || _ivl_sva2_cnt0 != 2)
      $fatal(1, "unexpected match counts %0d %0d %0d",
             _ivl_sva0_cnt0, _ivl_sva1_cnt0, _ivl_sva2_cnt0);
    $display("PASS");
    $finish(0);
  end
endmodule
