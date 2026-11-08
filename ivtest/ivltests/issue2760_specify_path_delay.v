`timescale 1ns/1ps
module issue2760_specify_path_delay_leaf(input a, output y);
  assign y = a;
  specify
    specparam cap = 1;
    (a => y) = 1.4 * cap + 0.7;
  endspecify
endmodule

module issue2760_specify_path_delay;
  reg a = 0;
  wire y;
  issue2760_specify_path_delay_leaf dut(a, y);

  initial begin
    $monitor("%0t a=%b y=%b", $time, a, y);
    #3;
    #1 a = 1;
    #2.05;
    if (y !== 1'b0) $fatal(1, "path delay completed too early");
    #0.05;
    if (y !== 1'b1) $fatal(1, "path delay did not complete at 2.1ns");
    $finish;
  end
endmodule
