// Only the invalid solve-before clause differs from the legal external-state
// constraint in sv_constraint_external_handle_state.v.
class clock_cfg;
  rand int unsigned clk_freq_mhz;
endclass

class host_seq;
  clock_cfg cfg;
  rand bit [1:0] speed_mode;

  constraint frequency_mode_c {
    solve cfg.clk_freq_mhz before speed_mode;
    if (cfg.clk_freq_mhz < 4) speed_mode == 0;
    else if (cfg.clk_freq_mhz < 8) speed_mode inside {0, 1};
    else speed_mode inside {0, 1, 2};
  }
endclass

module top;
  host_seq seq;
  initial begin
    seq = new;
    seq.cfg = new;
    seq.cfg.clk_freq_mhz = 8;
    if (seq.randomize())
      $fatal(1, "solve-before accepted a field outside the active rand set");
    if (seq.cfg.clk_freq_mhz != 8)
      $fatal(1, "failed randomization changed external cfg state");
    $display("PASS: external cfg solve-before is rejected");
  end
endmodule
