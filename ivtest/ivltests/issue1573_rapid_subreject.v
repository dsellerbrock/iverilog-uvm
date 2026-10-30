`timescale 1ns/1ps
module issue1573_source(input wire value, output wire q);
  assign q = value;
endmodule

module issue1573_load(input wire d, output wire q);
  assign q = d;
endmodule

module issue1573_specify(input wire d, output wire q);
  assign q = d;
  specify
    (d => q) = 10;
  endspecify
endmodule

module issue1573_rapid_subreject;
  reg value = 0;
  wire source_q, interconnect_q;
  wire specify_q;
  integer interconnect_count = 0, specify_count = 0;
  issue1573_source s(value, source_q);
  issue1573_load l(source_q, interconnect_q);
  issue1573_specify p(value, specify_q);

  always @(interconnect_q) interconnect_count = interconnect_count + 1;
  always @(specify_q) specify_count = specify_count + 1;

  initial begin
    $sdf_annotate("ivltests/issue1573_rapid_subreject.sdf", issue1573_rapid_subreject);
    #1 value = 1;
    #20 value = 0;
    #20;
    interconnect_count = 0;
    specify_count = 0;
    #2 value = 1;
    #1 value = 0;
    #15;
    if (interconnect_count != 0 || specify_count != 0)
      $fatal(1, "isolated sub-reject pulse escaped: interconnect=%0d specify=%0d",
             interconnect_count, specify_count);
    repeat (32) #1 value = ~value;
    #15;
    if (interconnect_count != 0 || specify_count != 0)
      $fatal(1, "rapid sub-reject pulses escaped: interconnect=%0d specify=%0d",
             interconnect_count, specify_count);
    $display("PASS: specify and interconnect sub-reject pulses suppressed");
    $finish;
  end
endmodule
