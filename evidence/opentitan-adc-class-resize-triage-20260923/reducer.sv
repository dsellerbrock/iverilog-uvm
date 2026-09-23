typedef struct packed { bit value; } filter_t;

class cfg_t;
  rand filter_t filter_cfg[][];
  constraint size_c { filter_cfg.size == 2; }
endclass

module reducer;
  cfg_t cfg = new;
  initial begin
    if (!cfg.randomize()) $fatal(1, "randomize failed");
    if (cfg.filter_cfg.size() != 2) $fatal(1, "wrong outer size");
    $display("PASS");
  end
endmodule
