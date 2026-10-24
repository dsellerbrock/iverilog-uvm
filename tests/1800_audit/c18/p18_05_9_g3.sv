class L;
  rand bit [3:0] x;
  constraint c { x > 10; }
endclass
class Q;
  L l;
  rand bit [3:0] y;
  constraint k { y == l.x; }
endclass

module p18_05_9_g3;
  Q q;
  int bad;
  initial begin
    q = new;
    q.l = new;
    q.l.x = 3;
    bad = 0;
    repeat (50) begin
      if (!q.randomize()) bad++;
      else if (q.y != 3 || q.l.x != 3) bad++;
    end
    $display("G3 bad=%0d", bad);
  end
endmodule
