// M7 stress: register-model FRONT-DOOR access. Now part of the standard
// sweep (was quarantined in tests/wip/). Exercises the full RAL front
// door: sequence -> sequencer -> driver over a real bus, then reads back
// through the register model. Passes with checks=4 writes=4 reads=4.
//
// This test pinned down "Finding 4"
// (docs/conformance/m7_stress_findings_2026-07-18.md), which was two
// independent defects, both now fixed:
//   1. Parameterized-class SPECIALIZATION: a `Class#(args) handle`
//      declaration now specializes, and virtual overrides of a
//      specialized class are emitted so dispatch through a parameterized
//      base handle reaches the override (pform.cc + elab_scope.cc; see
//      tests/m1b_typeparam_member_call_test.sv).
//   2. Virtual-dispatch OUTPUT copy-back: a virtual task with an
//      `output` argument dispatched via `%fork/v`, whose caller is itself
//      an output-argument task (the `get_next_item(req)` port shape),
//      dropped the returned handle because do_join left the base
//      call-site frame at the write head (vvp/vthread.cc; see
//      tests/m1b_virtual_output_copyback_test.sv).
`timescale 1ns/1ns
`include "uvm_macros.svh"
import uvm_pkg::*;

class m7_bus_txn extends uvm_sequence_item;
  rand bit [31:0] addr;
  rand bit [31:0] data;
  rand bit        is_write;
  `uvm_object_utils(m7_bus_txn)
  function new(string name = "m7_bus_txn");
    super.new(name);
  endfunction
endclass

// Bus driver with a private little memory: writes store, reads give
// the stored value back through the req item (no separate responses).
class m7_bus_driver extends uvm_driver #(m7_bus_txn);
  `uvm_component_utils(m7_bus_driver)
  bit [31:0] mem [bit [31:0]];
  int unsigned n_writes = 0;
  int unsigned n_reads  = 0;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    m7_bus_txn req;
    forever begin
      seq_item_port.get_next_item(req);
      #2;
      if (req.is_write) begin
        mem[req.addr] = req.data;
        n_writes += 1;
      end else begin
        req.data = mem.exists(req.addr) ? mem[req.addr] : 32'hdead_beef;
        n_reads += 1;
      end
      seq_item_port.item_done();
    end
  endtask
endclass

class m7_reg_adapter extends uvm_reg_adapter;
  `uvm_object_utils(m7_reg_adapter)
  function new(string name = "m7_reg_adapter");
    super.new(name);
    supports_byte_enable = 0;
    provides_responses   = 0;
  endfunction

  virtual function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
    m7_bus_txn txn = m7_bus_txn::type_id::create("txn");
    txn.addr     = rw.addr;
    txn.data     = rw.data;
    txn.is_write = (rw.kind == UVM_WRITE);
    return txn;
  endfunction

  virtual function void bus2reg(uvm_sequence_item bus_item,
                                ref uvm_reg_bus_op rw);
    m7_bus_txn txn;
    if (!$cast(txn, bus_item)) begin
      `uvm_fatal("ADAPT", "bus item is not an m7_bus_txn")
      return;
    end
    rw.kind   = txn.is_write ? UVM_WRITE : UVM_READ;
    rw.addr   = txn.addr;
    rw.data   = txn.data;
    rw.status = UVM_IS_OK;
  endfunction
endclass

class m7_reg32 extends uvm_reg;
  `uvm_object_utils(m7_reg32)
  rand uvm_reg_field value;

  function new(string name = "m7_reg32");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    value = uvm_reg_field::type_id::create("value");
    value.configure(this, 32, 0, "RW", 0, 32'h0, 1, 1, 1);
  endfunction
endclass

class m7_reg_block extends uvm_reg_block;
  `uvm_object_utils(m7_reg_block)
  rand m7_reg32 r0;
  rand m7_reg32 r1;
  rand m7_reg32 r2;

  function new(string name = "m7_reg_block");
    super.new(name, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    r0 = m7_reg32::type_id::create("r0");
    r0.build();
    r0.configure(this, null, "");
    r1 = m7_reg32::type_id::create("r1");
    r1.build();
    r1.configure(this, null, "");
    r2 = m7_reg32::type_id::create("r2");
    r2.build();
    r2.configure(this, null, "");
    default_map = create_map("default_map", 'h0, 4, UVM_LITTLE_ENDIAN);
    default_map.add_reg(r0, 'h0, "RW");
    default_map.add_reg(r1, 'h4, "RW");
    default_map.add_reg(r2, 'h8, "RW");
    lock_model();
  endfunction
endclass

class m7_reg_frontdoor_stress extends uvm_test;
  `uvm_component_utils(m7_reg_frontdoor_stress)
  m7_bus_driver drv;
  uvm_sequencer #(m7_bus_txn) sqr;
  m7_reg_block  model;
  m7_reg_adapter adapter;
  int unsigned checks_ok = 0;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    drv = m7_bus_driver::type_id::create("drv", this);
    sqr = uvm_sequencer #(m7_bus_txn)::type_id::create("sqr", this);
    model = m7_reg_block::type_id::create("model");
    model.build();
    adapter = m7_reg_adapter::type_id::create("adapter");
  endfunction

  function void connect_phase(uvm_phase phase);
    drv.seq_item_port.connect(sqr.seq_item_export);
    model.default_map.set_sequencer(sqr, adapter);
    model.default_map.set_auto_predict(1);
  endfunction

  task check_reg(m7_reg32 r, bit [31:0] wval);
    uvm_status_e   status;
    uvm_reg_data_t rval;
    r.write(status, wval);
    if (status != UVM_IS_OK)
      `uvm_error("REGWR", $sformatf("%s write status %s", r.get_name(), status.name()))
    r.read(status, rval);
    if (status != UVM_IS_OK)
      `uvm_error("REGRD", $sformatf("%s read status %s", r.get_name(), status.name()))
    if (rval !== wval)
      `uvm_error("REGRDV", $sformatf("%s read 0x%0h, wrote 0x%0h", r.get_name(), rval, wval))
    else if (r.get_mirrored_value() !== wval)
      `uvm_error("REGMIR", $sformatf("%s mirror 0x%0h, want 0x%0h", r.get_name(), r.get_mirrored_value(), wval))
    else
      checks_ok += 1;
  endtask

  task run_phase(uvm_phase phase);
    uvm_status_e   status;
    uvm_reg_data_t rval;
    phase.raise_objection(this);

    check_reg(model.r0, 32'h1111_2222);
    check_reg(model.r1, 32'hcafe_f00d);
    check_reg(model.r2, 32'h0badc0de);

    // Desired-value + update(): set() marks r1 dirty, update() emits
    // exactly one bus write, and the readback must see the new value.
    model.r1.set(32'h5555_aaaa);
    if (model.r1.needs_update()) begin
      model.r1.update(status);
      if (status != UVM_IS_OK)
        `uvm_error("REGUPD", "r1 update() failed")
      model.r1.read(status, rval);
      if (rval === 32'h5555_aaaa)
        checks_ok += 1;
      else
        `uvm_error("REGUPDV", $sformatf("r1 after update() reads 0x%0h", rval))
    end else begin
      `uvm_error("REGUPDN", "r1 needs_update() false after set()")
    end

    if (checks_ok == 4 && drv.n_writes == 4 && drv.n_reads == 4)
      $display("PASS: reg front-door stress (checks=%0d writes=%0d reads=%0d)",
               checks_ok, drv.n_writes, drv.n_reads);
    else
      $display("FAIL: checks=%0d (want 4) writes=%0d (want 4) reads=%0d (want 4)",
               checks_ok, drv.n_writes, drv.n_reads);

    phase.drop_objection(this);
  endtask
endclass

module m7_reg_frontdoor_stress_test;
  import uvm_pkg::*;
  initial run_test("m7_reg_frontdoor_stress");
endmodule
