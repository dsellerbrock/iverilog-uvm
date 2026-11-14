// An X/Z state operand in a nonground dist weight must fail randomization.
class seq_cfg_t;
  logic [7:0] four[2][2];
endclass
class env_cfg_t;
  seq_cfg_t seq_cfg;
endclass
class C;
  env_cfg_t cfg;
  rand bit pick;
  rand bit [7:0] q[$];
  constraint c {
    q.size() == 1;
    pick dist {
      1'b0 :/ (cfg.seq_cfg.four[0][1] + q.size()),
      1'b1 :/ 1
    };
  }
endclass
module top;
  C c;
  initial begin
    c = new;
    c.cfg = new;
    c.cfg.seq_cfg = new;
    c.cfg.seq_cfg.four[0][1] = 'x;
    if (c.randomize()) $fatal(1, "X weight accepted");
    if (c.pick != 0 || c.q.size() != 0)
      $fatal(1, "failed randomization changed values");
    $display("PASSED");
  end
endmodule
