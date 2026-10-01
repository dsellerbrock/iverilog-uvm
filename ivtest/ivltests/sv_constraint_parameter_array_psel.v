package P;
  parameter int InfoTypeSize[3] = '{1, 2, 3};
endpackage
import P::*;
class C;
  rand bit [1:0] pick;
  rand bit [7:0] selected;
  rand bit q[1][3][$];
  constraint c {
    pick inside {[0:2]};
    selected == P::InfoTypeSize[pick];
    foreach (q[i,j]) q[i][j].size() == InfoTypeSize[j];
  }
endclass
module test;
  C c;
  initial begin
    c = new;
    repeat (4) begin
      if (!c.randomize()) $fatal(1, "valid package parameter selection rejected");
      if (c.selected != P::InfoTypeSize[c.pick])
        $fatal(1, "wrong selected value");
      foreach (c.q[i,j])
        if (c.q[i][j].size() != P::InfoTypeSize[j])
          $fatal(1, "wrong queue size at %0d,%0d", i, j);
    end
    $display("PASSED");
  end
endmodule
