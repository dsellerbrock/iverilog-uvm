class L;
  rand bit [3:0] x;
  constraint c { x > 10; }
endclass
class P;
  rand L l;
  rand bit [3:0] y;
  constraint k { y == l.x + 1; }
endclass

module p18_05_9_g2;
  P p;
  int bad;
  initial begin
    p = new;
    p.l = new;
    bad = 0;
    repeat (50) begin
      if (!p.randomize()) bad++;
      else if (!(p.l.x inside {[11:14]} && p.y == p.l.x + 1)) bad++;
    end
    $display("G2 bad=%0d", bad);
  end
endmodule
