`timescale 1ns/1ps
// Small UVM env: sequence -> driver -> DUT -> monitor -> scoreboard.
`include "uvm_macros.svh"
import uvm_pkg::*;
interface bus_if(input logic clk);
  logic valid; logic [31:0] data; logic [31:0] result;
endinterface
module dut(bus_if b);
  always @(posedge b.clk) if (b.valid) b.result <= b.data * 3 + 1;
endmodule
class item extends uvm_sequence_item;
  rand bit [31:0] data;
  `uvm_object_utils(item)
  function new(string name="item"); super.new(name); endfunction
endclass
class seq extends uvm_sequence #(item);
  `uvm_object_utils(seq)
  int n = 5000;
  function new(string name="seq"); super.new(name); endfunction
  task body(); repeat (n) begin item it = item::type_id::create("it"); start_item(it); if (!it.randomize()) `uvm_fatal("R","rand") finish_item(it); end endtask
endclass
class drv extends uvm_driver #(item);
  `uvm_component_utils(drv)
  virtual bus_if vif;
  function new(string n, uvm_component p); super.new(n,p); endfunction
  task run_phase(uvm_phase phase);
    vif.valid <= 0;
    forever begin seq_item_port.get_next_item(req);
      @(posedge vif.clk); vif.valid <= 1; vif.data <= req.data;
      @(posedge vif.clk); vif.valid <= 0;
      seq_item_port.item_done(); end
  endtask
endclass
class mon extends uvm_monitor;
  `uvm_component_utils(mon)
  virtual bus_if vif; uvm_analysis_port #(item) ap;
  function new(string n, uvm_component p); super.new(n,p); ap = new("ap", this); endfunction
  task run_phase(uvm_phase phase);
    forever begin @(posedge vif.clk); if (vif.valid) begin item it = item::type_id::create("m"); it.data = vif.data; ap.write(it); end end
  endtask
endclass
class sb extends uvm_scoreboard;
  `uvm_component_utils(sb)
  uvm_analysis_imp #(item, sb) imp; int checked = 0; bit [31:0] acc;
  function new(string n, uvm_component p); super.new(n,p); imp = new("imp", this); endfunction
  function void write(item t); acc += t.data*3+1; checked++; endfunction
  function void report_phase(uvm_phase phase); `uvm_info("SB", $sformatf("checked=%0d acc=%h", checked, acc), UVM_NONE) endfunction
endclass
class env extends uvm_env;
  `uvm_component_utils(env)
  drv d; mon m; sb s; uvm_sequencer #(item) sqr;
  function new(string n, uvm_component p); super.new(n,p); endfunction
  function void build_phase(uvm_phase phase);
    d = drv::type_id::create("d", this); m = mon::type_id::create("m", this);
    s = sb::type_id::create("s", this); sqr = uvm_sequencer#(item)::type_id::create("sqr", this);
    if (!uvm_config_db#(virtual bus_if)::get(this, "", "vif", d.vif)) `uvm_fatal("V","vif")
    m.vif = d.vif;
  endfunction
  function void connect_phase(uvm_phase phase); d.seq_item_port.connect(sqr.seq_item_export); m.ap.connect(s.imp); endfunction
endclass
class test extends uvm_test;
  `uvm_component_utils(test)
  env e;
  function new(string n, uvm_component p); super.new(n,p); endfunction
  function void build_phase(uvm_phase phase); e = env::type_id::create("e", this); endfunction
  task run_phase(uvm_phase phase); seq s = seq::type_id::create("s"); phase.raise_objection(this); s.start(e.sqr); #20; phase.drop_objection(this); endtask
endclass
module top;
  logic clk = 0; always #5 clk = ~clk;
  bus_if b(clk); dut u(b);
  initial begin uvm_config_db#(virtual bus_if)::set(null, "*", "vif", b); run_test("test"); end
endmodule
