`timescale 1ns/1ps
module issue1563_device_dut(input a, output y);
  assign y = a;
  specify (a => y) = (0, 0);
  endspecify
endmodule

module issue1563_device;
  reg a = 0;
  wire y;
  issue1563_device_dut u(a, y);

  always @(y) $display("Y %0t %b", $time, y);

  initial begin
    $sdf_annotate("ivltests/issue1563_device.sdf", issue1563_device);
    #10 a = 1;
    #10 a = 0;
    #20 $finish;
  end
endmodule
