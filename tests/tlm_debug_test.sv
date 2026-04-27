`include "uvm_macros.svh"
import uvm_pkg::*;

class my_trans extends uvm_sequence_item;
  int value;
  `uvm_object_utils(my_trans)
  function new(string name = "my_trans");
    super.new(name);
  endfunction
endclass

class my_consumer extends uvm_component;
  uvm_blocking_put_imp #(my_trans, my_consumer) put_export;
  `uvm_component_utils(my_consumer)
  function new(string name, uvm_component parent);
    super.new(name, parent);
    put_export = new("put_export", this);
  endfunction
  task put(my_trans t);
    $display("CONSUMER: received value=%0d", t.value);
    if (t.value == 42)
      $display("TLM test PASSED!");
    else
      $display("TLM test FAILED! expected 42 got %0d", t.value);
  endtask
endclass

class my_producer extends uvm_component;
  uvm_blocking_put_port #(my_trans) put_port;
  `uvm_component_utils(my_producer)
  function new(string name, uvm_component parent);
    super.new(name, parent);
    put_port = new("put_port", this);
  endfunction
  task run_phase(uvm_phase phase);
    my_trans t;
    t = my_trans::type_id::create("t");
    t.value = 42;
    $display("DBG: put_port.size=%0d", put_port.size());
    put_port.put(t);
  endtask
endclass

class tlm_debug_test extends uvm_test;
  my_producer prod;
  my_consumer cons;
  `uvm_component_utils(tlm_debug_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    prod = my_producer::type_id::create("prod", this);
    cons = my_consumer::type_id::create("cons", this);
  endfunction
  function void connect_phase(uvm_phase phase);
    prod.put_port.connect(cons.put_export);
  endfunction
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    #1;
    phase.drop_objection(this);
  endtask
endclass

module top;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  initial begin
    run_test("tlm_debug_test");
  end
endmodule
