typedef struct packed { bit en; } entry_t;
class C;
  rand bit bias;
  rand entry_t q[2][2][$];
  constraint size_c { foreach (q[i,j]) q[i][j].size() == 1; }
  constraint order_c { solve bias before q[0][0][0], q[0][1][0], q[1][0][0], q[1][1][0]; }
  constraint content_c { if (bias) foreach (q[i,j,k]) q[i][j][k].en == 0; }
endclass
module test;
  C c; int ones;
  initial begin c=new; repeat (400) begin if (!c.randomize()) $fatal(1, "randomize failed"); ones += c.bias; end
    if (ones inside {[150:250]}) $display("PASSED");
    else $fatal(1, "ordered bias frequency out of range: %0d", ones);
  end
endmodule
