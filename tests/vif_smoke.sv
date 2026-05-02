// Minimal virtual interface smoke test.  The DUT uses plain module
// ports (not modport-typed) so the always_ff drives count without
// hitting the modport-direction-enforcement gap (Phase 63a A1
// captured modports for parsing but not full lvalue writes).
interface counter_if(input logic clk);
  logic [7:0] count;
  logic       reset;
endinterface

module counter(input logic clk, input logic reset, output logic [7:0] count);
  always @(posedge clk or posedge reset)
    if (reset) count <= 0;
    else       count <= count + 1;
endmodule

`include "uvm_macros.svh"
import uvm_pkg::*;

class counter_seq_item extends uvm_sequence_item;
  rand bit       do_reset;
  `uvm_object_utils(counter_seq_item)
  function new(string name = "counter_seq_item");
    super.new(name);
  endfunction
endclass

class counter_driver extends uvm_driver #(counter_seq_item);
  virtual counter_if vif;
  `uvm_component_utils(counter_driver)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    if (!uvm_config_db #(virtual counter_if)::get(this, "", "vif", vif))
      `uvm_fatal("NO_VIF", "vif not found in config_db")
  endfunction
  task run_phase(uvm_phase phase);
    counter_seq_item req;
    forever begin
      seq_item_port.get_next_item(req);
      @(posedge vif.clk);
      vif.reset <= req.do_reset;
      seq_item_port.item_done();
    end
  endtask
endclass

class counter_seq extends uvm_sequence #(counter_seq_item);
  `uvm_object_utils(counter_seq)
  function new(string name = "counter_seq"); super.new(name); endfunction
  task body();
    counter_seq_item req;
    req = counter_seq_item::type_id::create("req");
    start_item(req);
    req.do_reset = 1;
    finish_item(req);
    repeat (5) begin
      req = counter_seq_item::type_id::create("req");
      start_item(req);
      req.do_reset = 0;
      finish_item(req);
    end
  endtask
endclass

class counter_test extends uvm_test;
  `uvm_component_utils(counter_test)
  counter_driver drv;
  uvm_sequencer #(counter_seq_item) sqr;
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    drv = counter_driver::type_id::create("drv", this);
    sqr = uvm_sequencer #(counter_seq_item)::type_id::create("sqr", this);
  endfunction
  function void connect_phase(uvm_phase phase);
    drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction
  task run_phase(uvm_phase phase);
    counter_seq seq;
    phase.raise_objection(this);
    seq = counter_seq::type_id::create("seq");
    seq.start(sqr);
    $display("PASS counter_test");
    phase.drop_objection(this);
  endtask
endclass

module top;
  logic clk;
  initial clk = 0;
  always #5 clk = ~clk;

  counter_if dut_if(.clk(clk));
  counter    dut(.clk(clk), .reset(dut_if.reset), .count(dut_if.count));

  initial begin
    uvm_config_db #(virtual counter_if)::set(null, "uvm_test_top.*", "vif", dut_if);
    run_test("counter_test");
  end
endmodule
