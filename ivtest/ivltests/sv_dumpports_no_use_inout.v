// Cross-target collateral: merely declaring an inout must not introduce the
// private hierarchy boundary used by designs that actually call $dumpports.
module dumpports_no_use_leaf(inout wire pin, input wire enable);
  assign pin = enable ? 1'b1 : 1'bz;
endmodule

module sv_dumpports_no_use_inout;
  reg fixture_enable = 1'b1;
  reg dut_enable = 1'b0;
  tri pin;

  assign pin = fixture_enable ? 1'b0 : 1'bz;
  dumpports_no_use_leaf dut(pin, dut_enable);

  initial begin
    #1 if (pin !== 1'b0) $fatal(1, "fixture-to-DUT connectivity lost");
    #1 begin
      fixture_enable = 1'b0;
      dut_enable = 1'b1;
    end
    #1 if (pin !== 1'b1) $fatal(1, "DUT-to-fixture connectivity lost");
    $display("PASSED");
  end
endmodule
