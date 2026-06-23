// $value$plusargs writes to a VECTOR (int/bit/logic) class property.
//
// iverilog emitted a throwaway thread-stack temporary (no write-back) for a
// vector class property used as a $value$plusargs lvalue, so the assignment
// was silently dropped.  This is the OpenTitan dv_base_test pattern:
//   void'($value$plusargs("max_quit_count=%0d", max_quit_count));   // class prop
//   void'($value$plusargs("test_timeout_ns=%0d", test_timeout_ns));
// which left those (and drain_time_ns) at their defaults on every OT test.
//
// Fixed with a class-property-vector VPI lvalue handle (&CPV<sig,pidx>),
// the value-typed analog of the string handle (&CPS).
`include "uvm_macros.svh"
import uvm_pkg::*;

class my_cfg extends uvm_object;
  `uvm_object_utils(my_cfg)
  int          quit_count;
  bit   [31:0] addr;
  logic [7:0]  mask;
  longint      timeout_ns;
  int          untouched;
  function new(string name="my_cfg");
    super.new(name);
    quit_count = 1;
    addr       = 32'hdead;
    mask       = 8'h0f;
    timeout_ns = 64'd1;
    untouched  = 99;
  endfunction
endclass

class my_test extends uvm_test;
  `uvm_component_utils(my_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  task run_phase(uvm_phase phase);
    my_cfg cfg;
    phase.raise_objection(this);
    cfg = my_cfg::type_id::create("cfg");
    void'($value$plusargs("QUIT=%0d",  cfg.quit_count));
    void'($value$plusargs("ADDR=%0h",  cfg.addr));
    void'($value$plusargs("MASK=%0b",  cfg.mask));
    void'($value$plusargs("TMO=%0d",   cfg.timeout_ns));
    void'($value$plusargs("ABSENT=%0d", cfg.untouched)); // not supplied
    `uvm_info("TEST", $sformatf("quit=%0d addr=%0h mask=%0b tmo=%0d untouched=%0d",
              cfg.quit_count, cfg.addr, cfg.mask, cfg.timeout_ns, cfg.untouched), UVM_LOW)
    if (cfg.quit_count == 100 && cfg.addr == 32'hbeef &&
        cfg.mask == 8'b1111_0000 && cfg.timeout_ns == 64'd2000000 &&
        cfg.untouched == 99)
      `uvm_info("TEST", "CPV_PASS", UVM_LOW)
    else
      `uvm_error("TEST", $sformatf("CPV_FAIL quit=%0d addr=%0h mask=%0b tmo=%0d untouched=%0d",
                 cfg.quit_count, cfg.addr, cfg.mask, cfg.timeout_ns, cfg.untouched))
    phase.drop_objection(this);
  endtask
endclass

module top;
  initial run_test("my_test");
endmodule
