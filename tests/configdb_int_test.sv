import uvm_pkg::*;
`include "uvm_macros.svh"

class my_comp extends uvm_component;
  `uvm_component_utils(my_comp)
  int n;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    $display("build_phase: calling config_db::get");
    if (!uvm_config_db#(int)::get(this, "", "k", n))
      `uvm_fatal("NO_KEY", "key not found in config_db")
    $display("build_phase: got n=%0d", n);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    if (n == 42)
      $display("PASS: int match");
    else
      $display("FAIL: expected 42 got %0d", n);
    phase.drop_objection(this);
  endtask
endclass

class my_test extends uvm_test;
  `uvm_component_utils(my_test)
  my_comp comp;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    comp = my_comp::type_id::create("comp", this);
  endfunction
endclass

module top;
  initial begin
    uvm_config_db#(int)::set(null, "uvm_test_top.comp", "k", 42);
    run_test("my_test");
  end
endmodule
