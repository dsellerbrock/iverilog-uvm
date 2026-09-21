typedef struct {
  rand bit lane[2];
} config_t;

class config_holder;
  rand config_t cfg;

  constraint lanes_c {
    foreach (cfg.lane[i]) {
      cfg.lane[i] == (i == 1);
    }
  }
endclass

module test;
  initial begin
    static config_holder h = new;
    if (!h.randomize()) $fatal(1, "randomize failed");
    if (h.cfg.lane[0] !== 0 || h.cfg.lane[1] !== 1)
      $fatal(1, "foreach member constraint lost: %b%b",
             h.cfg.lane[1], h.cfg.lane[0]);
    $display("PASS constraint foreach struct member");
  end
endmodule
