class i2c_repro_cfg;
  rand int unsigned clk_freq_mhz;
endclass
class i2c_repro_seq;
  i2c_repro_cfg cfg;
  rand int unsigned speed_mode;
  constraint min_peri_clk_period_c {
`ifndef OMIT_STATE_SOLVE_ORDER
    solve cfg.clk_freq_mhz before speed_mode;
`endif
    if (cfg.clk_freq_mhz < 4) speed_mode == 0;
    else if (cfg.clk_freq_mhz < 8) speed_mode inside {0, 1};
    else speed_mode inside {0, 1, 2};
  }
  function new(); cfg = new; cfg.clk_freq_mhz = 3; endfunction
endclass
module i2c_state_solve_before_repro;
  i2c_repro_seq seq;
  initial begin
    seq = new;
    for (int freq = 3; freq <= 9; freq += 3) begin
      seq.cfg.clk_freq_mhz = freq;
      repeat (5) begin
        if (!seq.randomize()) $fatal(1, "speed randomize failed");
        if (seq.speed_mode > (freq < 4 ? 0 : freq < 8 ? 1 : 2))
          $fatal(1, "wrong mode %0d at %0d MHz", seq.speed_mode, freq);
      end
    end
    $display("PASS state clock modes");
  end
endmodule
