// M1 / G22 UVM-level regression: factory by-name creation through the
// canonical IEEE 1800.2 accessor chain uvm_factory::get().create_object_by_name.
// Language root cause was method dispatch on function-call results
// (IEEE 1800-2017 8.10); this confirms the unmodified Accellera flow.
import uvm_pkg::*;
`include "uvm_macros.svh"

class m1_factory_obj extends uvm_object;
  `uvm_object_utils(m1_factory_obj)
  function new(string name = "m1_factory_obj");
    super.new(name);
  endfunction
endclass

module m1_uvm_factory_by_name_test;
  initial begin
    uvm_object obj;
    m1_factory_obj mo;
    int errors = 0;

    obj = uvm_factory::get().create_object_by_name("m1_factory_obj", "", "inst1");
    if (obj == null) begin
      $display("FAIL: create_object_by_name returned null");
      errors++;
    end else if (!$cast(mo, obj)) begin
      $display("FAIL: cast to m1_factory_obj failed");
      errors++;
    end else if (mo.get_name() != "inst1") begin
      $display("FAIL: created name = %s, expected inst1", mo.get_name());
      errors++;
    end

    if (errors == 0) $display("PASS");
    $finish;
  end
endmodule
