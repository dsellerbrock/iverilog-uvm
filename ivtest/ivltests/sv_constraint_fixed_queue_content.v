typedef struct packed { bit en; bit [3:0] tag; } entry_t;
class C;
  rand entry_t q[2][2][$];
  constraint c {
    q[1][1][1].tag == 8;
    foreach (q[i,j]) {
      q[i][j].size() == 2;
      foreach (q[i][j][k]) {
        q[i][j][k].tag == i*4+j*2+k+1;
        q[i][j][k].en dist {1'b1 := 4, 1'b0 := 1};
        q[i][j][k].en == 1;
      }
    }
  }
endclass
module test;
  C c;
  initial begin
    c = new;
    if (!c.randomize()) $fatal(1, "randomize failed");
    foreach (c.q[i,j,k])
      if (c.q[i][j][k].tag != i*4+j*2+k+1 || c.q[i][j][k].en != 1)
        $fatal(1, "wrong content at %0d %0d %0d", i, j, k);
    $display("PASSED");
  end
endmodule
