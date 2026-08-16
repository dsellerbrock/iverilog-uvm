// This small inout design is also the seed for raw-VVP metadata validation
// cases in run_dumpports_focus.py.
module dumpports_metadata_leaf(inout wire [3:0] io);
  assign io = 4'bzzzz;
endmodule

module sv_dumpports_metadata_base;
  tri [3:0] io;
  reg [3:0] fixture = 4'bzzzz;
  assign io = fixture;
  dumpports_metadata_leaf dut(io);

  initial begin
    $dumpports(dut, "work/sv_dumpports_metadata_base.evcd");
    #1 $display("PASSED");
  end
endmodule
