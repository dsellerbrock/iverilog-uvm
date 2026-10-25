module issue1182_sva_boolean;
  bit clk = 0;
  logic [1:0] value = 2'b01;
  int pass_count, fail_count, if_truth;
  always #5 clk = ~clk;
  assert property (@(posedge clk) value) pass_count++; else fail_count++;
  initial begin
    #6 value = 2'bxx;
    #10 value = 2'bzz;
    #10 value = 2'b00;
    #10 value = 2'b10;
    #10;
    if (value) if_truth = 1;
    if (pass_count != 2 || fail_count != 3 || if_truth != 1)
      $fatal(1, "pass=%0d fail=%0d", pass_count, fail_count);
    $display("PASSED");
    $finish;
  end
endmodule
