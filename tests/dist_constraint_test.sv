// Phase 8: dist constraint lowered to inside — enforces range bounds
`include "uvm_macros.svh"
import uvm_pkg::*;

class clk_cfg extends uvm_object;
  `uvm_object_utils(clk_cfg)
  rand int unsigned clk_freq_mhz;
  constraint clk_freq_c {
    clk_freq_mhz dist { [5:23] :/ 2, [24:25] :/ 2, [26:47] :/ 1,
                        [48:50] :/ 2, [51:95] :/ 1, 96 :/ 1, 100 :/ 1 };
  }
  function new(string name="clk_cfg"); super.new(name); endfunction
endclass

class my_test extends uvm_test;
  `uvm_component_utils(my_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  task run_phase(uvm_phase phase);
    clk_cfg cfg = clk_cfg::type_id::create("cfg");
    int ok = 1;
    phase.raise_objection(this);
    repeat (20) begin
      void'(cfg.randomize());
      if (cfg.clk_freq_mhz < 5 || cfg.clk_freq_mhz > 100) begin
        `uvm_error("TEST", $sformatf("FAIL: clk_freq_mhz=%0d out of [5:100]", cfg.clk_freq_mhz))
        ok = 0;
      end
    end
    if (ok)
      `uvm_info("TEST", "PHASE8_PASS: all clk_freq_mhz in [5:100]", UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass

module top;
  initial run_test("my_test");
endmodule
