`timescale 1ns/1ps
module test;
  logic clk = 0, a = 0, b = 0;
  int failures = 0;
  always #5 clk = ~clk;

  // The sequence has matches at both offsets. Its match item assigns a
  // property-local variable, which the continuation checks after the
  // earliest match (IEEE 1800-2017/2023 16.9.8, 16.10).
  property p_first_match;
    int selected_time;
    @(posedge clk) a |->
      (first_match(a ##[1:2] b, selected_time = $time)
       ##1 (selected_time == 25));
  endproperty
  assert property (p_first_match) else failures++;

  initial begin
    @(negedge clk); a = 1;
    @(negedge clk); a = 0; b = 1;
    @(negedge clk); b = 1;
    @(negedge clk); b = 0;
    repeat (2) @(negedge clk);

    if (failures != 0)
      $fatal(1, "§16.9.8 expected the earliest-match local value; failures=%0d",
             failures);
    $display("PASSED: §16.9.8 first_match preserved its earliest-match local value");
    $finish(0);
  end
endmodule
