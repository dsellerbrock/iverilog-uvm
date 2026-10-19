typedef struct packed { bit [7:0] value; } filter_t;

class cfg_t;
  rand filter_t filter_cfg[][];
  constraint sizes_c {
    filter_cfg.size == 2;
    foreach (filter_cfg[channel]) filter_cfg[channel].size == 3;
    foreach (filter_cfg[channel, row])
      filter_cfg[channel][row].value == 8'(channel * 10 + row);
  }
endclass

module reducer;
  cfg_t cfg = new;
  initial begin
    if (!cfg.randomize()) $fatal(1, "randomize failed");
    if (cfg.filter_cfg.size() != 2) $fatal(1, "wrong outer size");
    foreach (cfg.filter_cfg[channel]) begin
      if (cfg.filter_cfg[channel].size() != 3)
        $fatal(1, "wrong inner size at %0d", channel);
      foreach (cfg.filter_cfg[channel, row])
        if (cfg.filter_cfg[channel][row].value != 8'(channel * 10 + row))
          $fatal(1, "wrong value at %0d,%0d", channel, row);
    end
    $display("PASS");
  end
endmodule
