`timescale 1ns/1ps

`ifdef WRONG_BIT
`define UNDELAYED_SELECTED_PATH
`endif
`ifdef OVERLAP_BIT
`define UNDELAYED_SELECTED_PATH
`endif

module tb;
  reg in;
  wire out;
  selected_top dut(out, in);

  initial begin
    in = 1'b0;
    $sdf_annotate("ivltests/sdf_selected_resolver_bit.sdf");
    #1 in = 1'b1;
    #0.005;
`ifdef EXTEND_BIT
    if (dut.bus[4] !== 1'b1) $fatal(1, "selected source did not change");
`else
    if (dut.bus[1] !== 1'b1) $fatal(1, "selected source did not change");
`endif
`ifdef UNDELAYED_SELECTED_PATH
    if (out !== 1'b1) $fatal(1, "rejected path was delayed");
`else
    if (out !== 1'b0) $fatal(1, "matching path changed too early");
`endif
    #0.006;
    if (out !== 1'b1) $fatal(1, "rising value did not reach sink");

    #1 in = 1'b0;
    #0.005;
`ifdef UNDELAYED_SELECTED_PATH
    if (out !== 1'b0) $fatal(1, "rejected falling path was delayed");
`else
    if (out !== 1'b1) $fatal(1, "matching falling path changed too early");
`endif
    #0.006;
    if (out !== 1'b0) $fatal(1, "falling value did not reach sink");
`ifdef WRONG_BIT
    $display("PASS: wrong-bit SDF path rejected");
`endif
`ifdef OVERLAP_BIT
    $display("PASS: overlapping SDF path rejected");
`endif
`ifndef UNDELAYED_SELECTED_PATH
    $display("PASS: selected resolver bit path");
`endif
  end
endmodule

module selected_top(output wire out, input wire in);
`ifdef EXTEND_BIT
  wire [5:0] bus;
  assign bus[0] = in;
  selected_buff pre1(.Y(bus[1]), .A(bus[0]));
  selected_buff pre2(.Y(bus[2]), .A(bus[1]));
  selected_buff pre3(.Y(bus[3]), .A(bus[2]));
  selected_buff src(.Y(bus[4]), .A(bus[3]));
  selected_buff tail(.Y(bus[5]), .A(bus[4]));
  selected_buff sink(.Y(out), .A(bus[4]));
`else
  wire [2:0] bus;
  assign bus[0] = in;
  selected_buff src(.Y(bus[1]), .A(bus[0]));
`ifdef OVERLAP_BIT
  selected_buff second_src(.Y(bus[1]), .A(bus[0]));
`endif
  selected_buff tail(.Y(bus[2]), .A(bus[1]));
`ifdef WRONG_BIT
  selected_buff sink(.Y(out), .A(bus[2]));
`else
  selected_buff sink(.Y(out), .A(bus[1]));
`endif
`endif
endmodule

module selected_buff(output wire Y, input wire A);
  buf (Y, A);
  specify
    (A => Y) = 0;
  endspecify
endmodule
