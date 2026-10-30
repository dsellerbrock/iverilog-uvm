`timescale 1ns/1ps

module issue1571_leaf(input wire a, output wire y);
  assign y = a;
endmodule

module issue1571_dut(input wire a, output wire y);
  issue1571_leaf u2(.a(a), .y(y));
endmodule

module issue1571_interconnect_source_direction;
  reg a;
  wire y;
  issue1571_dut u0(.a(a), .y(y));

  initial begin
    $sdf_annotate("ivltests/issue1571_interconnect_source_direction.sdf", issue1571_interconnect_source_direction);
    a = 1'b0;
    #10 a = 1'b1;
    #2;
    if (y !== 1'b1)
      $fatal(1, "invalid input source delayed load: %b", y);
    $display("PASS: invalid input INTERCONNECT source ignored");
    $finish;
  end
endmodule
