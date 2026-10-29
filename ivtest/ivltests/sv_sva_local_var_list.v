module sv_sva_local_var_list;
  bit clk = 0, a = 0, b = 0;
  int passes = 0, failures = 0;

  always #5 clk = ~clk;

  sequence valid_sequence;
    bit first_value, unused_value;
    (a, first_value = 1) ##1 (b && first_value);
  endsequence

  assert property (@(posedge clk) valid_sequence)
    passes++;
  else failures++;

  initial begin
    #1 a = 1;
    #10 b = 1;
    #6 a = 0;
    #1;
    if (passes != 1 || failures != 0)
      $fatal(1, "passes=%0d failures=%0d", passes, failures);
    $display("PASSED");
    $finish(0);
  end
endmodule
