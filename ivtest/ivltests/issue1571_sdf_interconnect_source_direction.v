`timescale 1ns/1ps

module issue1571_source(input wire a, output wire y);
  assign y = a;
endmodule

module issue1571_sink(input wire a, output wire y);
  assign y = a;
endmodule

module issue1571_output_load(output wire y);
  assign y = 1'bz;
endmodule

module issue1571_dut(input wire bad_a, input wire good_a,
                     output wire bad_y, output wire good_y,
                     output wire bad_load_y);
  wire good_net;
  wire bad_load_net;

  issue1571_sink u_bad(.a(bad_a), .y(bad_y));
  issue1571_source u_src(.a(good_a), .y(good_net));
  issue1571_sink u_good(.a(good_net), .y(good_y));
  issue1571_source u_load_src(.a(good_a), .y(bad_load_net));
  issue1571_output_load u_bad_load(.y(bad_load_net));
  assign bad_load_y = bad_load_net;
endmodule

module issue1571_sdf_interconnect_source_direction;
  reg drive;
  wire bad_y;
  wire good_y;
  wire bad_load_y;

  issue1571_dut u0(.bad_a(drive), .good_a(drive),
                   .bad_y(bad_y), .good_y(good_y),
                   .bad_load_y(bad_load_y));

  initial begin
    $sdf_annotate("ivltests/issue1571_sdf_interconnect_source_direction.sdf", u0);
    drive = 1'b0;
    #10 drive = 1'b1;
    #1;
    if (bad_y !== 1'b1)
      $fatal(1, "input source was incorrectly delayed: bad_y=%b", bad_y);
    if (bad_load_y !== 1'b1)
      $fatal(1, "output load was incorrectly delayed: bad_load_y=%b", bad_load_y);
    if (good_y !== 1'b0)
      $fatal(1, "output source did not retain its 3 ns delay: good_y=%b", good_y);
    #3;
    if (good_y !== 1'b1)
      $fatal(1, "output source did not arrive at 3 ns: good_y=%b", good_y);
    $display("input source and output load rejected; output source delayed 3 ns");
    $finish;
  end
endmodule
