import uvm_pkg::*;
`include "uvm_macros.svh"

class my_comp extends uvm_component;
  `uvm_component_utils(my_comp)
  string s;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    string fn;
    super.build_phase(phase);
    fn = get_full_name();
    $display("build_phase: my full_name=%s", fn);
    $display("build_phase: calling config_db::get");
    if (!uvm_config_db#(string)::get(this, "", "k", s))
      `uvm_fatal("NO_KEY", "key not found in config_db")
    $display("build_phase: got s=%s", s);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    if (s == "hello")
      $display("PASS: string match");
    else
      $display("FAIL: expected hello got %s", s);
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
    string my_fn;
    super.build_phase(phase);
    my_fn = get_full_name();
    $display("my_test full_name=%s", my_fn);
    comp = my_comp::type_id::create("comp", this);
  endfunction
endclass

module top;
  initial begin
    $display("TOP: before set");
    uvm_config_db#(string)::set(null, "uvm_test_top.comp", "k", "hello");
    $display("TOP: after set, calling run_test");
    run_test("my_test");
  end
endmodule
