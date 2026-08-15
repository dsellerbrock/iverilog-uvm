// Purely structural cross-target reducer for an ordinary inout hierarchy.
module dumpports_no_use_synth_leaf(inout wire pin, input wire dut_enable);
  assign pin = dut_enable ? 1'b1 : 1'bz;
endmodule

module sv_dumpports_no_use_inout_synth(
    input  wire fixture_enable,
    input  wire dut_enable,
    output wire observed
);
  tri pin;
  assign pin = fixture_enable ? 1'b0 : 1'bz;
  assign observed = pin;
  dumpports_no_use_synth_leaf dut(pin, dut_enable);
endmodule
