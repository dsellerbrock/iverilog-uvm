// IEEE 1800-2017/2023 23.11/27.5: interface-target legality is checked for
// the selected concrete occurrence. An inactive interface alternative must
// not poison a legal module target reached through the same generate name.
package sv_bind_interface_inactive_alternative_counts;
  int hits;
endpackage

interface sv_bind_interface_inactive_alternative_intf;
endinterface

module sv_bind_interface_inactive_alternative_leaf;
  localparam int TAG = 7;
endmodule

module sv_bind_interface_inactive_alternative_probe(input int observed);
  initial begin
    if (observed == 7)
      sv_bind_interface_inactive_alternative_counts::hits =
        sv_bind_interface_inactive_alternative_counts::hits + 1;
  end
endmodule

module sv_bind_interface_inactive_alternative_holder #(
  parameter bit USE_INTERFACE = 1'b0
);
  if (USE_INTERFACE) begin : selected
    sv_bind_interface_inactive_alternative_intf child();
  end else begin : selected
    sv_bind_interface_inactive_alternative_leaf child();
  end

  bind selected.child sv_bind_interface_inactive_alternative_probe
    p(.observed(TAG));
endmodule

module sv_bind_interface_inactive_alternative;
  sv_bind_interface_inactive_alternative_holder #(
    .USE_INTERFACE(1'b0)
  ) owner();

  initial begin
    #1;
    if (sv_bind_interface_inactive_alternative_counts::hits == 1)
      $display("PASSED");
    else
      $display("FAILED: hits=%0d",
               sv_bind_interface_inactive_alternative_counts::hits);
  end
endmodule
