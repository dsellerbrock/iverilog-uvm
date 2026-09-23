// IEEE 1800-2017 18.5.8.1 / 2023 18.5.7.1: a foreach array
// identifier may traverse more than one caller-owned class member.
class spi_cmd_info_t;
  bit enabled;
endclass

class spi_host_agent_cfg_t;
  spi_cmd_info_t cmd_infos[bit [7:0]];
endclass

class spi_config_t;
  spi_host_agent_cfg_t spi_host_agent_cfg;
  function new(); spi_host_agent_cfg = new(); endfunction
endclass

class spi_opcode_t;
  rand bit [7:0] opcode;
  function bit choose(input spi_config_t cfg);
    return this.randomize() with {
      opcode inside {8, 9, 200};
      foreach (cfg.spi_host_agent_cfg.cmd_infos[j]) {
        opcode != j;
      }
    };
  endfunction
  function bit choose_empty(input spi_config_t cfg);
    return this.randomize() with {
      opcode == 0;
      foreach (cfg.spi_host_agent_cfg.cmd_infos[j]) { opcode != 0; }
    };
  endfunction
  function bit choose_conflict(input spi_config_t cfg);
    return this.randomize() with {
      opcode inside {8, 200};
      foreach (cfg.spi_host_agent_cfg.cmd_infos[j]) { opcode != j; }
    };
  endfunction
endclass

module test;
  spi_config_t cfg = new;
  spi_opcode_t item = new;
  initial begin
    cfg.spi_host_agent_cfg.cmd_infos[8] = new;
    cfg.spi_host_agent_cfg.cmd_infos[200] = new;
    if (!item.randomize() with {
        item.opcode inside {8, 9, 200};
        foreach (cfg.spi_host_agent_cfg.cmd_infos[j]) {
          item.opcode != j;
        }
      } || item.opcode != 9)
      $fatal(1, "explicit target path ignored associative keys");
    if (!item.choose(cfg) || item.opcode != 9)
      $fatal(1, "populated hierarchical foreach was not enforced");
    if (item.choose_conflict(cfg) || item.opcode != 9)
      $fatal(1, "contradictory foreach changed the original value");
    cfg.spi_host_agent_cfg.cmd_infos.delete();
    if (!item.choose_empty(cfg) || item.opcode != 0)
      $fatal(1, "empty hierarchical foreach was not vacuous");
    $display("PASSED");
  end
endmodule
