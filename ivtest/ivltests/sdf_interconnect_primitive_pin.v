`timescale 1ns/1ps
module sdf_interconnect_primitive_pin_source(output wire y);
  reg drive;
  assign y = drive;
  initial begin
    drive = 0;
    #10 drive = 1;
  end
endmodule

module sdf_interconnect_primitive_pin_sink(input wire a, output wire y);
  assign y = a;
endmodule

module sdf_interconnect_primitive_pin;
  wire src, result, gate_result;
  sdf_interconnect_primitive_pin_source u1(.y(src));
  sdf_interconnect_primitive_pin_sink u2(.a(src), .y(result));
  and g1(gate_result, src, 1'b1);

  initial begin
    $sdf_annotate("ivltests/sdf_interconnect_primitive_pin.sdf", sdf_interconnect_primitive_pin);
    $monitor("t=%0t result=%b", $time, result);
    #20 $finish;
  end
endmodule
