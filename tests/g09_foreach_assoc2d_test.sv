// g09_foreach_assoc2d_test.sv — foreach over a 2-D associative array (assoc of assoc).
// G09: inner loop body never executed because foreach elaboration fell through to
// an integer for-loop instead of building nested aa/first+next loops.
`include "uvm_macros.svh"
import uvm_pkg::*;

class g09_foreach_assoc2d_test extends uvm_test;
  `uvm_component_utils(g09_foreach_assoc2d_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    int aa[string][string];
    int count;
    int tmp1[string];
    int tmp2[string];
    phase.raise_objection(this);

    // Populate via 1-D intermediates to avoid aliasing.
    tmp1["x"] = 1;
    tmp1["y"] = 2;
    aa["a"] = tmp1;

    tmp2["p"] = 3;
    aa["b"] = tmp2;

    count = 0;
    foreach (aa[k1, k2]) begin
      count++;
    end

    if (count == 3)
      `uvm_info("G09", "PASS: foreach assoc2d visited all 3 entries", UVM_NONE)
    else
      `uvm_error("G09", $sformatf("FAIL: visited %0d entries, expected 3", count))

    phase.drop_objection(this);
  endtask
endclass

module top;
  initial run_test("g09_foreach_assoc2d_test");
endmodule
