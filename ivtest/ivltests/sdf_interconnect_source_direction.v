`timescale 1ns/1ps

module leaf(input wire a, output wire y);
  assign y = a;
endmodule

module bad_dut(input wire a, output wire y);
  leaf u2(.a(a), .y(y));
endmodule

module good_dut(input wire a, output wire y);
  wire link;
  leaf u1(.a(a), .y(link));
  leaf u2(.a(link), .y(y));
endmodule

module top;
  reg drive;
  wire bad_y, good_y;

  bad_dut bad(.a(drive), .y(bad_y));
  good_dut good(.a(drive), .y(good_y));

  initial begin
    $sdf_annotate("ivltests/sdf_interconnect_source_direction.sdf", top);
    $monitor("t=%0t bad=%b good=%b", $realtime, bad_y, good_y);
    drive = 0;
    #10 drive = 1;
    #5 $finish;
  end
endmodule
