program P(input bit clk, input bit value);
  int passed = 0, failed = 0, covered = 0;
  assert property (@(posedge clk) value) passed++; else failed++;
  cover property (@(posedge clk) value) covered++;
  initial begin
    #26;
    if (passed != 2 || failed != 1 || covered != 2) begin
      $display("FAIL: pass=%0d fail=%0d cover=%0d", passed, failed, covered);
      $finish_and_return(1);
    end
    $display("PASS");
    $finish;
  end
endprogram

module issue3010_program_assertion;
  bit clk = 0, value = 0;
  P p(clk, value);
  always #5 clk = ~clk;
  initial #10 value = 1;
endmodule
