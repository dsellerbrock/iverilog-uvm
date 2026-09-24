`timescale 1ns/1ps
module sampled_pure_vs_impure;
  bit clk = 0;
  bit trigger = 0;
  bit data = 0;
  int direct_failures = 0;
  int pure_failures = 0;
  int impure_failures = 0;
  int impure_calls = 0;

  always #5 clk = ~clk;
  always @(posedge clk) if ($time == 25) data <= 1;

  function automatic bit pure_check(input bit value);
    return value;
  endfunction

  // Deliberately illegal in an assertion expression under IEEE 1800 16.6.
  function automatic bit impure_check(input bit value);
    impure_calls++;
    $display("INNER time=%0t value=%0b", $time, value);
    return value;
  endfunction

  direct_check: assert property (@(posedge clk) trigger |=> data)
    else direct_failures++;
  pure_function_check: assert property (@(posedge clk) trigger |=> pure_check(data))
    else pure_failures++;
  impure_function_check: assert property (@(posedge clk) trigger |=> impure_check(data))
    else impure_failures++;

  initial begin
    #12 trigger = 1;
    #10 trigger = 0;
    #30;
    $display("SUMMARY direct=%0d pure=%0d impure=%0d calls=%0d data=%0b",
             direct_failures, pure_failures, impure_failures, impure_calls, data);
    if (direct_failures != 1 || pure_failures != 1 ||
        impure_failures != 1 || impure_calls != 5 || data != 1)
      $fatal(1, "sampled/implication control failed");
    $finish;
  end
endmodule
