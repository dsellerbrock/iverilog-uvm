class A; rand bit [3:0] v; endclass
class B extends A;
  rand A left, right;
  constraint heapcond { left.v <= v; right.v > v; }
endclass

module p18_05_9_g1s;
  B b;
  int bad, left_lt;
  initial begin
    b = new;
    b.left = new;
    b.right = new;
    bad = 0;
    left_lt = 0;
    repeat (200) begin
      if (!b.randomize()) bad++;
      else begin
        if (!(b.left.v <= b.v && b.right.v > b.v)) bad++;
        if (b.left.v < b.v) left_lt++;
      end
    end
    $display("G1S bad=%0d left_lt=%0d", bad, left_lt);
  end
endmodule
