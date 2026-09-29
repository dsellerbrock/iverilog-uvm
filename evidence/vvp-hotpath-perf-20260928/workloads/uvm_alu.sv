`timescale 1ns/1ps
// Representative UVM workload: constrained-random ALU transactions through
// sequencer -> driver -> DUT -> monitor -> scoreboard (reference model).
interface alu_if(input logic clk);
  logic        valid, ready, out_valid;
  logic [2:0]  op;
  logic [31:0] a, b, y;
endinterface

module alu(input logic clk, input logic rst_n, alu_if bus);
  logic busy;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin busy <= 0; bus.out_valid <= 0; bus.y <= 0; end
    else begin
      bus.out_valid <= 0;
      if (bus.valid && bus.ready) begin
        case (bus.op)
          3'd0: bus.y <= bus.a + bus.b;
          3'd1: bus.y <= bus.a - bus.b;
          3'd2: bus.y <= bus.a & bus.b;
          3'd3: bus.y <= bus.a | bus.b;
          3'd4: bus.y <= bus.a ^ bus.b;
          3'd5: bus.y <= bus.a << bus.b[4:0];
          3'd6: bus.y <= bus.a >> bus.b[4:0];
          default: bus.y <= bus.a * bus.b;
        endcase
        bus.out_valid <= 1;
      end
    end
  end
  assign bus.ready = rst_n;
endmodule

`include "uvm_macros.svh"
import uvm_pkg::*;

class alu_item extends uvm_sequence_item;
  rand bit [2:0]  op;
  rand bit [31:0] a, b;
  bit [31:0] y;
  constraint c_op { op dist { [0:4] := 3, [5:7] := 1 }; }
  constraint c_shift { op inside {5, 6} -> b < 32; }
  `uvm_object_utils_begin(alu_item)
    `uvm_field_int(op, UVM_ALL_ON)
    `uvm_field_int(a, UVM_ALL_ON)
    `uvm_field_int(b, UVM_ALL_ON)
  `uvm_object_utils_end
  function new(string name = "alu_item"); super.new(name); endfunction
endclass

class alu_seq extends uvm_sequence #(alu_item);
  `uvm_object_utils(alu_seq)
  int unsigned n = 100;
  function new(string name = "alu_seq"); super.new(name); endfunction
  task body();
    repeat (n) begin
      alu_item it = alu_item::type_id::create("it");
      start_item(it);
      if (!it.randomize()) `uvm_error("RND", "randomize failed")
      finish_item(it);
    end
  endtask
endclass

class alu_driver extends uvm_driver #(alu_item);
  `uvm_component_utils(alu_driver)
  virtual alu_if vif;
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    if (!uvm_config_db #(virtual alu_if)::get(this, "", "vif", vif)) `uvm_fatal("VIF", "no vif")
  endfunction
  task run_phase(uvm_phase phase);
    vif.valid <= 0;
    forever begin
      seq_item_port.get_next_item(req);
      @(posedge vif.clk);
      vif.valid <= 1; vif.op <= req.op; vif.a <= req.a; vif.b <= req.b;
      @(posedge vif.clk);
      while (!vif.ready) @(posedge vif.clk);
      vif.valid <= 0;
      `uvm_info("DRV", req.sprint(), UVM_HIGH)
      seq_item_port.item_done();
    end
  endtask
endclass

class alu_monitor extends uvm_monitor;
  `uvm_component_utils(alu_monitor)
  virtual alu_if vif;
  uvm_analysis_port #(alu_item) ap;
  function new(string name, uvm_component parent); super.new(name, parent); ap = new("ap", this); endfunction
  function void build_phase(uvm_phase phase);
    if (!uvm_config_db #(virtual alu_if)::get(this, "", "vif", vif)) `uvm_fatal("VIF", "no vif")
  endfunction
  task run_phase(uvm_phase phase);
    alu_item pend[$];
    forever begin
      @(posedge vif.clk);
      if (vif.out_valid && pend.size() > 0) begin
        alu_item t = pend.pop_front();
        t.y = vif.y;
        ap.write(t);
      end
      if (vif.valid && vif.ready) begin
        alu_item t = alu_item::type_id::create("mon");
        t.op = vif.op; t.a = vif.a; t.b = vif.b;
        pend.push_back(t);
      end
    end
  endtask
endclass

class alu_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(alu_scoreboard)
  uvm_analysis_imp #(alu_item, alu_scoreboard) imp;
  int unsigned checked, errors;
  function new(string name, uvm_component parent); super.new(name, parent); imp = new("imp", this); endfunction
  function bit [31:0] model(alu_item t);
    case (t.op)
      0: return t.a + t.b;   1: return t.a - t.b;  2: return t.a & t.b;
      3: return t.a | t.b;   4: return t.a ^ t.b;  5: return t.a << t.b[4:0];
      6: return t.a >> t.b[4:0];
      default: return t.a * t.b;
    endcase
  endfunction
  function void write(alu_item t);
    checked++;
    if (model(t) !== t.y) begin
      errors++;
      `uvm_error("SB", $sformatf("mismatch %s exp %h", t.sprint(), model(t)))
    end
  endfunction
  function void report_phase(uvm_phase phase);
    $display("SCOREBOARD checked=%0d errors=%0d", checked, errors);
  endfunction
endclass

class alu_test extends uvm_test;
  `uvm_component_utils(alu_test)
  alu_driver drv; alu_monitor mon; alu_scoreboard sb;
  uvm_sequencer #(alu_item) sqr;
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    drv = alu_driver::type_id::create("drv", this);
    mon = alu_monitor::type_id::create("mon", this);
    sb  = alu_scoreboard::type_id::create("sb", this);
    sqr = uvm_sequencer #(alu_item)::type_id::create("sqr", this);
  endfunction
  function void connect_phase(uvm_phase phase);
    drv.seq_item_port.connect(sqr.seq_item_export);
    mon.ap.connect(sb.imp);
  endfunction
  task run_phase(uvm_phase phase);
    alu_seq seq = alu_seq::type_id::create("seq");
    int unsigned n;
    if ($value$plusargs("N=%d", n)) seq.n = n;
    phase.raise_objection(this);
    seq.start(sqr);
    repeat (5) @(posedge drv.vif.clk);
    phase.drop_objection(this);
  endtask
endclass

module top;
  logic clk = 0, rst_n = 0;
  always #5 clk = ~clk;
  alu_if bus(clk);
  alu dut(clk, rst_n, bus);
  initial begin
    uvm_config_db #(virtual alu_if)::set(null, "uvm_test_top.*", "vif", bus);
    #22 rst_n = 1;
  end
  initial run_test("alu_test");
endmodule
