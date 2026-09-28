// IEEE 1800-2017/2023 7.8, 18.3, 18.4: a random associative key
// selects a live class-state fixed-array element at randomize().
typedef enum logic [3:0] {Data = 0, Info0 = 1, Info1 = 2, Info2 = 4} part_e;
typedef struct packed {part_e partition; bit [7:0] addr;} op_t;
class seq_cfg_t;
  logic [31:0] ecc_err_target = 1;
endclass
class cfg_t;
  seq_cfg_t seq_cfg;
  bit [1:0] tgt_pre[part_e][4];
  logic [1:0] four[part_e][4];
  function new;
    seq_cfg = new;
    tgt_pre[Data][1] = 2;
    tgt_pre[Data][3] = 2;
    tgt_pre[Info0][1] = 1;
    tgt_pre[Info1][1] = 3;
    tgt_pre[Info2][1] = 2;
    four[Data][1] = 1;
    four[Info1][1] = 'x;
  endfunction
endclass
class C;
  cfg_t cfg;
  part_e forced;
  bit enable = 1;
  int mode;
  rand op_t rand_op;
  constraint c {
    rand_op.partition == forced;
    if (enable) {
      if (mode == 0)
        rand_op.addr[1:0] == cfg.tgt_pre[rand_op.partition][cfg.seq_cfg.ecc_err_target];
      else
        rand_op.addr[1:0] == cfg.four[rand_op.partition][cfg.seq_cfg.ecc_err_target];
    }
  }
endclass
module top;
  C c;
  initial begin
    c = new;
    c.cfg = new;
    c.forced = Data;
    if (!c.randomize() || c.rand_op.addr[1:0] != 2) $fatal(1, "data key");
    c.forced = Info0;
    if (!c.randomize() || c.rand_op.addr[1:0] != 1) $fatal(1, "info key");
    c.forced = Info2;
    if (!c.randomize() || c.rand_op.addr[1:0] != 2) $fatal(1, "sparse info key");
    c.forced = Data;
    c.cfg.tgt_pre[Data][1] = 3;
    if (!c.randomize() || c.rand_op.addr[1:0] != 3) $fatal(1, "live state");
    c.cfg.seq_cfg.ecc_err_target = 3;
    if (!c.randomize() || c.rand_op.addr[1:0] != 2) $fatal(1, "last fixed child");
    c.cfg.seq_cfg.ecc_err_target = 4;
    if (!c.randomize() || c.rand_op.addr[1:0] != 0) $fatal(1, "2-state OOB");
    c.cfg.seq_cfg.ecc_err_target = 1;
    c.forced = part_e'(4'd3);
    if (!c.randomize() || c.rand_op.addr[1:0] != 0) $fatal(1, "missing key default");
    c.mode = 1;
    c.forced = Data;
    if (!c.randomize() || c.rand_op.addr[1:0] != 1) $fatal(1, "unselected X key");
    c.forced = Info1;
    if (c.randomize()) $fatal(1, "selected X key succeeded");
    c.enable = 0;
    if (!c.randomize()) $fatal(1, "inactive selected X key");
    c.enable = 1;
    c.forced = Data;
    c.cfg.seq_cfg.ecc_err_target = 4;
    if (c.randomize()) $fatal(1, "4-state OOB succeeded");
    c.mode = 0;
    c.cfg.seq_cfg.ecc_err_target = 'x;
    if (c.randomize()) $fatal(1, "selected X state index succeeded");
    c.cfg.seq_cfg = null;
    if (c.randomize()) $fatal(1, "selected inner null path succeeded");
    c.enable = 0;
    c.cfg = null;
    if (!c.randomize()) $fatal(1, "inactive null path");
    c.enable = 1;
    if (c.randomize()) $fatal(1, "selected null path succeeded");
    $display("PASSED");
  end
endmodule
