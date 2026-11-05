`timescale 1ns/1ps

module issue1563_sdf_device_no_specify_dut(
    input logic A, input logic B, output logic Y, output logic Z);
  assign Y = A;
  assign Z = B;
  specify
    (B => Z) = 0;
  endspecify
endmodule

module issue1563_sdf_device_no_specify;
  logic A = 0;
  logic B = 0;
  wire Y;
  wire Z;
  issue1563_sdf_device_no_specify_dut u(A, B, Y, Z);

  initial begin
    $sdf_annotate("ivltests/issue1563_sdf_device_no_specify.sdf");
    #10 A = 1;
    #1;
    if (Y !== 1)
      $fatal(1, "unexpected primitive-driven output value");
    $display("PASSED");
    $finish;
  end
endmodule
