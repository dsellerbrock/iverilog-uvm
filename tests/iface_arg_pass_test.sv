// Phase 46 repro: passing an interface instance as a function argument when
// the instance name shadows the interface type name (canonical OpenTitan tb
// pattern: `clk_rst_if clk_rst_if(.clk, .rst_n)`) was elaborating the bare
// reference as PETypename via `data_type` -> `typeref_t` instead of as a
// PEIdent looking up the instance scope. PETypename::elaborate_expr returned
// an empty string, so the function arg landed as null. Under OT this
// silently stored null in uvm_config_db, breaking the testbench wiring.

interface clk_rst_if(inout clk, inout rst_n);
  bit drive;
endinterface

module top;
  wire clk, rst_n;
  // Instance name == interface type name.
  clk_rst_if clk_rst_if(.clk, .rst_n);

  function automatic int check_iface(virtual clk_rst_if vif);
    if (vif == null) return 0;
    return 1;
  endfunction

  initial begin
    int got;
    got = check_iface(clk_rst_if);
    if (got == 1) $display("PASS got=%0d", got);
    else $display("FAIL got=%0d (vif was null!)", got);
    $finish;
  end
endmodule
