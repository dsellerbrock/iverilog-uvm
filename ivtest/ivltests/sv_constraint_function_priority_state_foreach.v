// IEEE 1800-2017/2023 18.5.12, 18.5.8: a class whose constraints call a function
// with a random argument (so function priority planning is active) and also hold a
// dynamic foreach whose dist weights are captured non-random state. Planning refused
// the foreach ("function calls inside dynamic foreach priority are not yet supported")
// although its calls have no random arguments and impose no order. OpenTitan
// flash_ctrl's mp_info_pages constraint has exactly this shape.
typedef struct packed { bit [3:0] en; bit [3:0] rd; } pg_t;
class seq_cfg; int unsigned en_pc[2][2]; int unsigned rd_pc[2][2]; endclass
class env_cfg; seq_cfg seq_cfg; function new; seq_cfg = new; endfunction endclass
class vseq;
  env_cfg cfg;
  rand bit [3:0] x, y;
  function bit [3:0] h(bit [3:0] a); return a + 1; endfunction
  constraint fc { y == h(x); x inside {[1:4]}; }
  rand pg_t pages[2][2][$];
  constraint c {
    foreach (pages[i, j]) {
      pages[i][j].size() == 3;
      foreach (pages[i][j][k]) {
        pages[i][j][k].en dist { 4'h5 :/ (100 - cfg.seq_cfg.en_pc[i][j]), 4'ha :/ cfg.seq_cfg.en_pc[i][j] };
        pages[i][j][k].rd dist { 4'h5 :/ (100 - cfg.seq_cfg.rd_pc[i][j]), 4'ha :/ cfg.seq_cfg.rd_pc[i][j] };
      }
    }
  }
endclass
module t;
  initial begin
    vseq v; int bad;
    v = new; bad = 0;
    v.cfg = new;
    foreach (v.cfg.seq_cfg.en_pc[i,j]) begin v.cfg.seq_cfg.en_pc[i][j] = (i+j)%2 ? 100 : 0; v.cfg.seq_cfg.rd_pc[i][j] = 100; end
    if (!v.randomize()) $display("FAIL randomize");
    else if (v.y !== v.x + 1) $display("FAILED function constraint x=%0d y=%0d", v.x, v.y);
    else begin
      foreach (v.pages[i,j,k]) begin
        if (v.pages[i][j][k].en !== (((i+j)%2) ? 4'ha : 4'h5) || v.pages[i][j][k].rd !== 4'ha) bad++;
      end
      if (bad) $display("FAILED %0d", bad); else $display("PASSED");
    end
  end
endmodule
