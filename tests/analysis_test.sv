`include "uvm_macros.svh"
import uvm_pkg::*;

class my_trans extends uvm_sequence_item;
  int value;
  `uvm_object_utils(my_trans)
  function new(string name = "my_trans");
    super.new(name);
  endfunction
endclass

class my_subscriber extends uvm_subscriber #(my_trans);
  `uvm_component_utils(my_subscriber)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  function void write(my_trans t);
    $display("SUBSCRIBER: write(value=%0d)", t.value);
    if (t.value == 99)
      $display("Analysis test PASSED!");
    else
      $display("Analysis test FAILED! expected 99 got %0d", t.value);
  endfunction
endclass

class my_monitor extends uvm_monitor;
  uvm_analysis_port #(my_trans) ap;
  `uvm_component_utils(my_monitor)
  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction
  task run_phase(uvm_phase phase);
    my_trans t;
    t = my_trans::type_id::create("t");
    t.value = 99;
    ap.write(t);
  endtask
endclass

class analysis_test extends uvm_test;
  my_monitor mon;
  my_subscriber sub;
  `uvm_component_utils(analysis_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    mon = my_monitor::type_id::create("mon", this);
    sub = my_subscriber::type_id::create("sub", this);
  endfunction
  function void connect_phase(uvm_phase phase);
    mon.ap.connect(sub.analysis_export);
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
    run_test("analysis_test");
  end
endmodule
