// M7 stress: register-model LAYER semantics — everything the RAL model
// does without touching a bus or DPI: reset values, desired vs
// mirrored value tracking, needs_update, predict(), multi-field
// packing, and address-map arithmetic. This is the register-model
// coverage that can run today; bus (front-door) traffic is exercised
// by tests/wip/m7_reg_frontdoor_stress_test.sv once finding 4 lands,
// and user-backdoor access by reg_basic_test.
`include "uvm_macros.svh"
import uvm_pkg::*;

class m7_two_field_reg extends uvm_reg;
  `uvm_object_utils(m7_two_field_reg)
  rand uvm_reg_field lo;
  rand uvm_reg_field hi;

  function new(string name = "m7_two_field_reg");
    super.new(name, 16, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    lo = uvm_reg_field::type_id::create("lo");
    lo.configure(this, 8, 0, "RW", 0, 8'h12, 1, 1, 1);
    hi = uvm_reg_field::type_id::create("hi");
    hi.configure(this, 8, 8, "RW", 0, 8'h34, 1, 1, 1);
  endfunction
endclass

class m7_sem_block extends uvm_reg_block;
  `uvm_object_utils(m7_sem_block)
  rand m7_two_field_reg r0;
  rand m7_two_field_reg r1;

  function new(string name = "m7_sem_block");
    super.new(name, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    r0 = m7_two_field_reg::type_id::create("r0");
    r0.build();
    r0.configure(this, null, "");
    r1 = m7_two_field_reg::type_id::create("r1");
    r1.build();
    r1.configure(this, null, "");
    default_map = create_map("default_map", 'h100, 4, UVM_LITTLE_ENDIAN);
    default_map.add_reg(r0, 'h0, "RW");
    default_map.add_reg(r1, 'h4, "RW");
    lock_model();
  endfunction
endclass

class m7_reg_model_semantics extends uvm_test;
  `uvm_component_utils(m7_reg_model_semantics)
  m7_sem_block model;
  int unsigned bad = 0;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    model = m7_sem_block::type_id::create("model");
    model.build();
  endfunction

  function void chk(bit cond, string what);
    if (!cond) begin
      bad += 1;
      `uvm_error("SEM", what)
    end
  endfunction

  task run_phase(uvm_phase phase);
    uvm_reg_data_t v;
    phase.raise_objection(this);

    // Structure: widths and field placement.
    begin
      uvm_reg_field flds[$];
      model.r0.get_fields(flds);
      chk(flds.size() == 2, "r0 field count != 2");
    end
    chk(model.r0.get_n_bits() == 16, "r0 width != 16");
    chk(model.r0.lo.get_lsb_pos() == 0, "lo lsb != 0");
    chk(model.r0.hi.get_lsb_pos() == 8, "hi lsb != 8");

    // Reset: mirrored and desired both come up at the field resets,
    // packed by lsb position (hi=0x34, lo=0x12 -> 0x3412).
    model.reset();
    chk(model.r0.get_reset() === 16'h3412, "r0 reset value != 0x3412");
    chk(model.r0.get_mirrored_value() === 16'h3412, "r0 mirrored after reset");
    chk(model.r0.get() === 16'h3412, "r0 desired after reset");
    chk(model.r0.needs_update() == 0, "needs_update after reset");

    // Desired vs mirrored: set() moves only the desired value.
    model.r0.set(16'habcd);
    chk(model.r0.get() === 16'habcd, "desired after set");
    chk(model.r0.get_mirrored_value() === 16'h3412, "mirrored unchanged by set");
    chk(model.r0.needs_update() == 1, "needs_update after set");

    // Field-level set packs into the register's desired value.
    model.r1.lo.set(8'h5a);
    model.r1.hi.set(8'ha5);
    chk(model.r1.get() === 16'ha55a, "field sets pack into desired");

    // predict() moves the mirror (and desired) without bus traffic.
    void'(model.r0.predict(16'h55aa));
    chk(model.r0.get_mirrored_value() === 16'h55aa, "mirrored after predict");
    chk(model.r0.needs_update() == 0, "needs_update after predict");
    chk(model.r0.lo.get_mirrored_value() === 8'haa, "lo field mirror slice");
    chk(model.r0.hi.get_mirrored_value() === 8'h55, "hi field mirror slice");

    // Address-map arithmetic: base 'h100, unit 4 bytes.
    chk(model.r0.get_offset(model.default_map) === 'h0, "r0 offset");
    chk(model.r1.get_offset(model.default_map) === 'h4, "r1 offset");
    // get_address() is NOT checked here: it reads the map_info.addr
    // cache that Xinit_address_mapX fills via
    // `m_regs_info[rg].addr = addrs`, and property stores through an
    // assoc-indexed class handle are silently mis-bound (finding 6 in
    // m7_stress_findings_2026-07-18.md). Restore these checks when
    // that lands:
    //   chk(model.r0.get_address(model.default_map) === 'h100, "r0 address");
    //   chk(model.r1.get_address(model.default_map) === 'h104, "r1 address");

    if (bad == 0)
      $display("PASS: register-model semantics (structure, reset, desired/mirrored, predict, map math)");
    else
      $display("FAIL: %0d register-model semantic checks failed", bad);

    phase.drop_objection(this);
  endtask
endclass

module m7_reg_model_semantics_test;
  import uvm_pkg::*;
  initial run_test("m7_reg_model_semantics");
endmodule
