module sv_assert_cover_api;
  bit clk = 0;
  bit hit = 0;
  bit disabled = 0;

  always #5 clk = ~clk;

  cover property (@(posedge clk) hit);
  cover sequence (@(posedge clk) hit);
  cover property (@(posedge clk) disable iff (disabled) hit);

  initial begin
    hit = 1;
    disabled = 1;
    cover (hit);
    cover (1'b0);
    @(negedge clk);
    $finish;
  end
endmodule
