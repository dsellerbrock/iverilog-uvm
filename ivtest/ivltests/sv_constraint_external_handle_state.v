// A non-rand class handle does not make its child rand properties part of
// this sequence's active random-object set. Those child values are state in
// ordinary constraints, but cannot be solve-before variables.
class clock_cfg;
  rand int unsigned clk_freq_mhz;
endclass

class host_seq;
  clock_cfg cfg;
  rand bit [1:0] speed_mode;

  constraint frequency_mode_c {
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
    for (int unsigned freq = 2; freq <= 8; freq += 3) begin
      seq.cfg.clk_freq_mhz = freq;
      repeat (20) begin
        if (!seq.randomize())
          $fatal(1, "legal external-state constraint failed");
        if (seq.cfg.clk_freq_mhz != freq)
          $fatal(1, "sequence randomize changed external cfg state");
        if ((freq < 4 && seq.speed_mode != 0) ||
            (freq >= 4 && freq < 8 && seq.speed_mode > 1) ||
            (freq >= 8 && seq.speed_mode > 2))
          $fatal(1, "speed_mode %0d is invalid at %0d MHz",
                 seq.speed_mode, freq);
      end
    end

    $display("PASS: external cfg state constrains mode without being randomized");
  end
endmodule
