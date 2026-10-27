class A; rand bit [7:0] v; endclass
class B extends A;
  rand A left, right;
  constraint heapcond { left.v <= v; right.v > v; }
endclass

module p18_05_9_g1;
  B b;
  int i, bad, rc;
  initial begin
    b = new;
    b.left = new;
    b.right = new;
    bad = 0;
    for (i = 0; i < 20; i++) begin
      rc = b.randomize();
      $display("G1 i=%0d rc=%0d v=%0d l=%0d r=%0d", i, rc, b.v, b.left.v, b.right.v);
      if (!rc || !(b.left.v <= b.v && b.right.v > b.v)) bad++;
    end
    $display("G1 bad=%0d", bad);
  end
endmodule
