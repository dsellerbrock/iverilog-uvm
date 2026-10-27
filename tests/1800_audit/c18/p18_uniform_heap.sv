class A; rand bit [7:0] v; endclass
class B extends A; rand A left, right; constraint heapcond { left.v <= v; right.v > v; } endclass
module p18_uniform_heap;
  B b; int n = 1000; real sl = 0, sv = 0, sr = 0; int lo = 0;
  initial begin b = new; b.left = new; b.right = new;
    repeat (n) begin void'(b.randomize()); sl += b.left.v; sv += b.v; sr += b.right.v; if (b.v < 32) lo++; end
    $display("H %0.2f %0.2f %0.2f %0d", sl/n, sv/n, sr/n, lo);
  end
endmodule
