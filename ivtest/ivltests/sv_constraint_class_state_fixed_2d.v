// IEEE 1800-2017/2023 18.3, 18.4 and fixed-array invalid reads.
class seq_cfg_2d;
  bit [3:0] weight[2][2];
  logic [3:0] four[2][2];
  int unsigned mp_info_page_en_pc[2][2];
endclass

class env_cfg_2d;
  seq_cfg_2d seq_cfg;
endclass

class fixed_state_2d;
  env_cfg_2d cfg;
  rand bit [3:0] row[2][2];
  rand bit [3:0] value;
  constraint state_reads {
    foreach (row[i,j]) row[i][j] == cfg.seq_cfg.weight[i][j];
    value == cfg.seq_cfg.weight[0][1];
  }
endclass

class fixed_state_2d_dist;
  env_cfg_2d cfg;
  rand bit mp_info_pages[2][2][$];
  constraint page_weights {
    foreach (mp_info_pages[i,j]) {
      mp_info_pages[i][j].size() == 1;
      foreach (mp_info_pages[i][j][k])
        mp_info_pages[i][j][k] dist {
          1'b0 :/ (100 - cfg.seq_cfg.mp_info_page_en_pc[i][j]),
          1'b1 :/ cfg.seq_cfg.mp_info_page_en_pc[i][j]
        };
    }
  }
endclass

class fixed_state_2d_guards;
  env_cfg_2d cfg;
  int mode;
  rand bit [3:0] value;
  constraint selected_read {
    if (mode == 0) value == 5;
    else if (mode == 1) value == cfg.seq_cfg.weight[2][0];
    else if (mode == 2) value == cfg.seq_cfg.four[2][0];
    else if (mode == 3) value == cfg.seq_cfg.four[0][1];
    else if (mode == 4) value == cfg.seq_cfg.weight[0][1];
  }
  constraint guarded_weight {
    if (mode == 5)
      value dist {
        0 :/ (100 - cfg.seq_cfg.mp_info_page_en_pc[0][0]),
        1 :/ cfg.seq_cfg.mp_info_page_en_pc[0][0]
      };
  }
endclass

module main;
  fixed_state_2d a;
  fixed_state_2d_dist d;
  fixed_state_2d_guards b;
  bit [3:0] saved;
  initial begin
    a = new;
    a.cfg = new;
    a.cfg.seq_cfg = new;
    a.cfg.seq_cfg.weight[0][0] = 1;
    a.cfg.seq_cfg.weight[0][1] = 2;
    a.cfg.seq_cfg.weight[1][0] = 3;
    a.cfg.seq_cfg.weight[1][1] = 4;
    if (!a.randomize() || a.value != 2 || a.row[0][0] != 1
        || a.row[0][1] != 2 || a.row[1][0] != 3 || a.row[1][1] != 4)
      $fatal(1, "selected 2-D state values were not solved");
    a.cfg.seq_cfg.weight[0][1] = 9;
    if (!a.randomize() || a.value != 9 || a.row[0][1] != 9)
      $fatal(1, "selected state was sampled before randomize()");

    d = new;
    d.cfg = a.cfg;
    d.cfg.seq_cfg.mp_info_page_en_pc[0][0] = 0;
    d.cfg.seq_cfg.mp_info_page_en_pc[0][1] = 100;
    d.cfg.seq_cfg.mp_info_page_en_pc[1][0] = 100;
    d.cfg.seq_cfg.mp_info_page_en_pc[1][1] = 0;
    if (!d.randomize() || d.mp_info_pages[0][0][0] != 0
        || d.mp_info_pages[0][1][0] != 1 || d.mp_info_pages[1][0][0] != 1
        || d.mp_info_pages[1][1][0] != 0)
      $fatal(1, "Flash-shaped queue dist did not read 2-D state weights");

    b = new;
    b.cfg = a.cfg;
    b.mode = 1;
    if (!b.randomize() || b.value != 0)
      $fatal(1, "two-state out-of-range read did not return zero");
    saved = b.value;
    b.mode = 2;
    if (b.randomize() || b.value != saved)
      $fatal(1, "active four-state out-of-range read did not fail and roll back");
    b.mode = 0;
    if (!b.randomize() || b.value != 5)
      $fatal(1, "inactive four-state invalid read was not guarded");
    b.cfg.seq_cfg.four[0][1] = 'x;
    b.mode = 3;
    if (b.randomize())
      $fatal(1, "selected X state element did not fail");
    b.mode = 0;
    b.cfg = null;
    if (!b.randomize() || b.value != 5)
      $fatal(1, "inactive null path was not guarded");
    b.mode = 4;
    if (b.randomize())
      $fatal(1, "selected null path did not fail");
    b.mode = 5;
    if (b.randomize())
      $fatal(1, "selected null dist weight did not fail");
    $display("PASSED");
  end
endmodule
