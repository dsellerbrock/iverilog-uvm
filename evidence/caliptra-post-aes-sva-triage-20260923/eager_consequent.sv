module eager_consequent;
  bit clk = 0;
  bit trigger = 0;
  int false_calls = 0;
  int true_calls = 0;
  int false_failures = 0;
  int true_failures = 0;
  int pure_false_failures = 0;
  int pure_true_failures = 0;

  always #5 clk = ~clk;

  function automatic bit impure_false();
    false_calls++;
    $display("INNER false-antecedent time=%0t", $time);
    return 0;
  endfunction

  function automatic bit impure_true();
    true_calls++;
    $display("INNER true-antecedent time=%0t", $time);
    return 0;
  endfunction

  function automatic bit check_pure();
    return 0;
  endfunction

  a_impure_false: assert property (@(posedge clk) 1'b0 |=> impure_false())
    else begin false_failures++; $display("OUTER impure false time=%0t", $time); end
  a_impure_true: assert property (@(posedge clk) trigger |=> impure_true())
    else begin true_failures++; $display("OUTER impure true time=%0t", $time); end
  a_pure_false: assert property (@(posedge clk) 1'b0 |=> check_pure())
    else begin pure_false_failures++; $display("OUTER pure false time=%0t", $time); end
  a_pure_true: assert property (@(posedge clk) trigger |=> check_pure())
    else begin pure_true_failures++; $display("OUTER pure true time=%0t", $time); end

  initial begin
    #12 trigger = 1;
    #10 trigger = 0;
    #30;
    $display("COUNTS false_calls=%0d true_calls=%0d false_failures=%0d true_failures=%0d pure_false_failures=%0d pure_true_failures=%0d", false_calls, true_calls, false_failures, true_failures, pure_false_failures, pure_true_failures);
    $finish;
  end
endmodule
