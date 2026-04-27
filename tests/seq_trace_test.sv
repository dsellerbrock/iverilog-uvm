`include "uvm_macros.svh"
import uvm_pkg::*;

class seq_item extends uvm_sequence_item;
  rand bit [7:0] data;
  `uvm_object_utils(seq_item)
  function new(string name = "seq_item");
    super.new(name);
  endfunction
endclass

class my_seq extends uvm_sequence #(seq_item);
  `uvm_object_utils(my_seq)
  function new(string name = "my_seq");
    super.new(name);
  endfunction
  task body();
    seq_item item;
    repeat (3) begin
      item = seq_item::type_id::create("item");
      start_item(item);
      void'(item.randomize());
      finish_item(item);
      $display("SEQ: sent data=%0d", item.data);
    end
  endtask
endclass

class my_driver extends uvm_driver #(seq_item);
  `uvm_component_utils(my_driver)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  task run_phase(uvm_phase phase);
    seq_item item;
    forever begin
      seq_item_port.get_next_item(item);
      $display("DRV: got data=%0d", item.data);
      seq_item_port.item_done();
    end
  endtask
endclass

class my_agent extends uvm_agent;
  my_driver drv;
  uvm_sequencer #(seq_item) sqr;
  `uvm_component_utils(my_agent)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    drv = my_driver::type_id::create("drv", this);
    sqr = uvm_sequencer #(seq_item)::type_id::create("sqr", this);
  endfunction
  function void connect_phase(uvm_phase phase);
    drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction
endclass

class seq_trace_test extends uvm_test;
  my_agent agent;
  `uvm_component_utils(seq_trace_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    agent = my_agent::type_id::create("agent", this);
  endfunction
  task run_phase(uvm_phase phase);
    my_seq seq;
    phase.raise_objection(this);
    seq = my_seq::type_id::create("seq");
    seq.start(agent.sqr);
    $display("Sequence trace test PASSED!");
    phase.drop_objection(this);
  endtask
endclass

module top;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  initial begin
    run_test("seq_trace_test");
  end
endmodule
