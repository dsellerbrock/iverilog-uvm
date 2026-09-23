// Must be rejected: the final component is scalar, not an array.
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
  initial if (item.choose(cfg)) $fatal(1, "nonarray foreach was accepted");
endmodule
