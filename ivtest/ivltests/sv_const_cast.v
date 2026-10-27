module sv_const_cast;
  bit clk = 0;
  int cnt = 1;
  int result;
  int failures = 0;

  always #5 clk = ~clk;
  always @(posedge clk) cnt <= cnt + 1;

  assert property (@(posedge clk) const'(cnt) != 2)
    else begin
      failures++;
      $display("assert failure time=%0t cnt=%0d", $time, cnt);
    end

  initial begin
    result = const'(cnt);
    $display("const=%0d bits=%0d", result, $bits(const'(cnt)));
    #26;
    $display("failures=%0d", failures);
    $finish;
  end
endmodule
