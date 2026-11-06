package issue2601_pkg;
  typedef enum bit { COND_IN = 0, COND_OUT = 1 } cond_e;
  typedef struct packed {
    cond_e cond;
    int min_v;
    int max_v;
    bit en;
  } fcfg_t;
  const fcfg_t DEF[] = '{
    '{COND_IN,   5,  99, 1'b1},
    '{COND_OUT, -3,   7, 1'b0},
    '{COND_IN, 100, 200, 1'b1},
    '{COND_OUT,  0, 999, 1'b1}
  };
endpackage

import issue2601_pkg::*;

class issue2601_base;
  rand fcfg_t f[][];
  constraint size_c {
    f.size == 2;
    foreach (f[ch]) f[ch].size == 4;
  }
endclass

class issue2601_soft extends issue2601_base;
  constraint default_c {
    foreach (f[ch, i]) soft f[ch][i] == DEF[i];
  }
endclass

class issue2601_hard extends issue2601_soft;
  constraint hard_c { f[1][2].min_v == 500; }
endclass

module main;
  initial begin
    issue2601_hard cfg;
    int defaults;

    cfg = new;
    if (!cfg.randomize()) $fatal(1, "randomize failed");
    if (cfg.f[1][2].min_v != 500)
      $fatal(1, "hard constraint not satisfied: min_v=%0d", cfg.f[1][2].min_v);
    defaults = 0;
    foreach (cfg.f[ch, i]) begin
      if (!(ch == 1 && i == 2) && cfg.f[ch][i] === DEF[i])
        defaults++;
    end
    if (defaults != 7)
      $fatal(1, "soft defaults retained for %0d leaves, expected 7", defaults);
    $display("PASS");
  end
endmodule
