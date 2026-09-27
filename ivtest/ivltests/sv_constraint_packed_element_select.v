// A select of a multi-dimensional packed value picks an element, not a bit
// (IEEE 1800-2017/2023 7.4.1): for `logic [1:0][15:0] seeds', seeds[1] is
// bits [31:16]. Constraints used to select bit 1 instead -- `seeds[1] ==
// 16'h1234' was silently unsatisfiable and `seeds[0] != 0' constrained one
// bit. A foreach may iterate packed dimensions (18.5.8; OpenTitan keymgr:
// foreach (local_flash.seeds[i]) in std::randomize() with). Declared ranges
// that do not end at 0, or ascend, shift the selected bits.
typedef struct packed { logic [1:0][15:0] seeds; } flash_t;
typedef struct packed { logic [0:1][7:0] asc; logic [8:1] off; } misc_t;

class c;
  rand flash_t f;
  rand misc_t m;
  constraint k {
    f.seeds[1] == 16'h1234;
    foreach (f.seeds[i]) f.seeds[i] != 0;
    m.asc[0] == 8'hA5;
    m.asc[1] == 8'h5A;
    m.off[8] == 1'b1;
    m.off[1] == 1'b0;
  }
endclass

module test;
  initial begin
    automatic c o = new;
    flash_t g;
    bit ok, sok;
    ok = o.randomize();
    sok = std::randomize(g) with {
      foreach (g.seeds[i]) { !(g.seeds[i] inside {0, '1}); }
      g.seeds[0] == 16'hbeef;
    };
    if (ok && o.f.seeds[1] == 16'h1234 && o.f.seeds[0] != 0
	&& o.m.asc[0] == 8'hA5 && o.m.asc[1] == 8'h5A
	&& o.m.off[8] == 1'b1 && o.m.off[1] == 1'b0
	&& sok && g.seeds[0] == 16'hbeef && g.seeds[1] != 0
	&& g.seeds[1] != 16'hffff)
      $display("PASSED");
    else
      $display("FAILED %0d %h %h %0d %h", ok, o.f, o.m, sok, g);
  end
endmodule
