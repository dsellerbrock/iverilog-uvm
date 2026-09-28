// A nonground dist weight is rejected and assigned zero weight. Its X/Z
// state check must not escape the private evaluator into the owning solve.
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
    if (!c.randomize()) $fatal(1, "rejected weight poisoned parent");
    if (c.pick != 1 || c.q.size() != 1)
      $fatal(1, "rejected weight retained a branch or wrong queue size");
    $display("PASSED");
  end
endmodule
