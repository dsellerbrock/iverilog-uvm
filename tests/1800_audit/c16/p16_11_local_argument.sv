module test;
  logic clk = 0, a = 0, b = 0;
  int call_count = 0, captured_value = 0;
  always #5 clk = ~clk;

  task automatic mark_argument(int value);
    call_count++;
    captured_value = value;
  endtask

  sequence s_local_argument;
    int value;
    @(posedge clk) (a, value = 42) ##1 (b, mark_argument(value));
  endsequence
  cover property (s_local_argument);

  initial begin
    @(negedge clk); a = 1;
    @(negedge clk); a = 0; b = 1;
    @(negedge clk); b = 0;
    repeat (2) @(negedge clk);
    if (call_count != 1 || captured_value != 42)
      $fatal(1, "§16.11 local argument: calls=%0d value=%0d", call_count, captured_value);
    $display("PASSED: §16.11 local variable passed by value");
    $finish(0);
  end
endmodule
