`timescale 1ns/1ps
module pulse_leaf(input a, output y);
  assign y = a;
  specify
    (a => y) = (4,4);
  endspecify
endmodule

module top;
  reg a = 0;
  wire y;
  pulse_leaf dut(a, y);

  initial begin
    $sdf_annotate("ivltests/sdf_pathpulse_warning.sdf");
    #10 a = 1;
    #2 a = 0;
    #10 $finish;
  end
endmodule
