// Compatibility extension: IEEE 1800-2017/2023 23.6 requires an instance
// array select in a hierarchical name to be constant. Commercial-style DV
// sources also use a runtime-selected interface instance where a virtual-
// interface value is expected. Icarus implements that form as an explicit
// runtime dispatch table; this test is not counted as IEEE 25.9 conformance.
interface sv_vif_instance_runtime_index_if;
endinterface

module sv_vif_instance_runtime_index_extension;
  sv_vif_instance_runtime_index_if buses[0:2]();
  virtual sv_vif_instance_runtime_index_if selected;
  int index;
  logic observed;

  initial begin
    index = 1;
    selected = buses[index];

    observed = 1'bx;
    observed = (selected == buses[index]);
    if (observed !== 1'b1)
      $fatal(1, "virtual interface did not equal runtime-selected instance");

    observed = 1'bx;
    observed = (buses[index] == selected);
    if (observed !== 1'b1)
      $fatal(1, "runtime-selected instance did not equal virtual interface");

    index = 2;

    observed = 1'bx;
    observed = (selected != buses[index]);
    if (observed !== 1'b1)
      $fatal(1, "virtual interface did not differ from runtime-selected instance");

    observed = 1'bx;
    observed = (buses[index] != selected);
    if (observed !== 1'b1)
      $fatal(1, "runtime-selected instance did not differ from virtual interface");

    selected = buses[index];

    observed = 1'bx;
    observed = (selected == buses[index]);
    if (observed !== 1'b1)
      $fatal(1, "rebound virtual interface did not equal selected instance");

    $display("PASSED");
  end
endmodule
