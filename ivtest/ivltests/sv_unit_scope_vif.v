// M5-4: a virtual-interface variable declared at compilation-unit ($unit)
// and package scope (IEEE 1800-2017 25.9, 3.12.1). Previously a syntax error:
// the $unit/package grammar reached the virtual-interface data_type only
// through a path made unreachable by the K_class lookahead after K_virtual,
// so a dedicated package_item alternative is needed (as at module scope).
interface simple_if;
  logic [7:0] d;
endinterface

// $unit-scope virtual-interface variables.
virtual simple_if g_vif;
virtual simple_if g_vif_arr[2];

package pkg;
  // package-scope virtual-interface variable (same grammar path).
  virtual simple_if p_vif;
endpackage

module sv_unit_scope_vif;
  import pkg::*;
  simple_if inst();
  simple_if inst2();
  int errors = 0;
  initial begin
    g_vif = inst;
    g_vif_arr[0] = inst;
    g_vif_arr[1] = inst2;
    p_vif = inst2;
    inst.d  = 8'hC3;
    inst2.d = 8'h5A;
    #1;
    if (g_vif.d        !== 8'hC3) begin $display("FAILED g_vif=%0h", g_vif.d); errors++; end
    if (g_vif_arr[0].d !== 8'hC3) begin $display("FAILED arr0=%0h", g_vif_arr[0].d); errors++; end
    if (g_vif_arr[1].d !== 8'h5A) begin $display("FAILED arr1=%0h", g_vif_arr[1].d); errors++; end
    if (p_vif.d        !== 8'h5A) begin $display("FAILED p_vif=%0h", p_vif.d); errors++; end
    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish;
  end
endmodule
