`timescale 1ns/1ps

module issue2473_sdf_timescale_dut(input a, output y);
  assign y = a;
  specify
    (a => y) = 1;
  endspecify
endmodule

module top;
  reg a = 0;
  wire y;
  reg saw_transition = 0;

  issue2473_sdf_timescale_dut dut(a, y);

  initial begin
    $sdf_annotate("ivltests/issue2473_sdf_timescale.sdf", top);
    #10 a = 1;
    #5;
    if (!saw_transition)
      $fatal(1, "SDF TIMESCALE delay was not applied");
    $display("PASSED");
    $finish;
  end

  always @(posedge y) begin
    if ($realtime != 14.0)
      $fatal(1, "expected transition at 14 ns, got %0t", $time);
    saw_transition = 1;
  end
endmodule
