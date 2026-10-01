// A foreach over an `int' iterates its bits: integer atom types are packed
// arrays [31:0] (IEEE 1800-2017/2023 7.4.1, 18.5.8), and slang accepts this.
// An earlier version of this test expected a rejection; that was wrong.
// Here j ranges over 0..31, so opcode must be at least 32.
class scalar_source_t;
  int cmd_infos;
endclass

class scalar_config_t;
  scalar_source_t source;
  function new(); source = new(); endfunction
endclass

class scalar_opcode_t;
  rand bit [7:0] opcode;
  function bit choose(input scalar_config_t cfg);
    return this.randomize() with {
      foreach (cfg.source.cmd_infos[j]) { opcode != j; }
    };
  endfunction
endclass

module test;
  scalar_config_t cfg = new;
  scalar_opcode_t item = new;
  initial begin
    bit ok;
    ok = 1;
    repeat (20) ok &= item.choose(cfg) && item.opcode >= 32;
    if (ok) $display("PASSED"); else $display("FAILED %0d", item.opcode);
  end
endmodule
