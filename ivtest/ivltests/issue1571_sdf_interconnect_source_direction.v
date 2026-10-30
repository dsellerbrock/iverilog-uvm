`timescale 1ns/1ps

module issue1571_sdf_buffer(input wire a, output wire y);
  assign y = a;
endmodule

module issue1571_sdf_dut(input wire a, input wire drive,
                         input wire load_bad_drive,
                         output wire bad_y, output wire good_y,
                         output wire load_bad_y);
  wire good_net;
  issue1571_sdf_buffer u1(.a(drive), .y(good_net));
  issue1571_sdf_buffer u2(.a(a), .y(bad_y));
  issue1571_sdf_buffer u3(.a(good_net), .y(good_y));
  issue1571_sdf_buffer u4(.a(load_bad_drive), .y(load_bad_y));
endmodule

module tb;
  reg bad_drive = 1'b0;
  reg good_drive = 1'b0;
  reg load_bad_drive = 1'b0;
  wire bad_y;
  wire good_y;
  wire load_bad_y;

  issue1571_sdf_dut u0(.a(bad_drive), .drive(good_drive),
                       .load_bad_drive(load_bad_drive), .bad_y(bad_y),
                       .good_y(good_y), .load_bad_y(load_bad_y));

  initial begin
    $sdf_annotate("ivltests/issue1571_sdf_interconnect_source_direction.sdf", tb);
    #10 bad_drive = 1'b1;
        good_drive = 1'b1;
        load_bad_drive = 1'b1;
    #1;
    if (bad_y !== 1'b1)
      $fatal(1, "input source annotation was applied: bad_y=%b", bad_y);
    if (load_bad_y !== 1'b1)
      $fatal(1, "output load annotation was applied: load_bad_y=%b", load_bad_y);
    if (good_y !== 1'b0)
      $fatal(1, "valid output source delay was not applied: good_y=%b", good_y);
    #3;
    if (good_y !== 1'b1)
      $fatal(1, "valid output source delay did not expire: good_y=%b", good_y);
    $display("PASS: invalid source/load rejected; valid output source delayed");
    $finish;
  end
endmodule
