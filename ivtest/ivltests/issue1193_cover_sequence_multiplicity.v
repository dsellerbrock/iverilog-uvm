module issue1193_cover_sequence_multiplicity;
  logic clk = 0, a = 1, b = 1;
  always #5 clk = ~clk;

  sequence s;
    a ##[0:1] b;
  endsequence

  cp: cover property (@(posedge clk) s);
  cs: cover sequence (@(posedge clk) s);

  initial begin
    #6 a = 0;
    #10;
    if (_ivl_sva0_cnt0 !== 1 || _ivl_sva1_cnt0 !== 2)
      $fatal(1, "cover multiplicity: property=%0d sequence=%0d",
             _ivl_sva0_cnt0, _ivl_sva1_cnt0);
    $display("property=%0d sequence=%0d", _ivl_sva0_cnt0, _ivl_sva1_cnt0);
    $finish;
  end
endmodule
