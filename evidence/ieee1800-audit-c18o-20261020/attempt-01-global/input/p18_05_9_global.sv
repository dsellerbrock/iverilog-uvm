class A; rand bit [7:0] v; endclass
class B extends A;
  rand A left, right;
  constraint heapcond { left.v <= v; right.v > v; }
endclass
class L;
  rand bit [3:0] x;
  constraint c { x > 10; }
endclass
class P;
  rand L l;
  rand bit [3:0] y;
  constraint k { y == l.x + 1; }
endclass
class Q;
  L l;
  rand bit [3:0] y;
  constraint k { y == l.x; }
endclass

module p18_05_9_global;
  B b;
  P p;
  Q q;
  int bad, dl, dr;
  initial begin
    b = new;
    b.left = new;
    b.right = new;
    bad = 0;
    dl = 0;
    dr = 0;
    repeat (200) begin
      if (!b.randomize()) bad++;
      else begin
        if (!(b.left.v <= b.v && b.right.v > b.v)) bad++;
        dl += (b.left.v != b.v);
        dr++;
      end
    end
    $display("G1 bad=%0d left_lt=%0d right_ok=%0d", bad, dl, dr);

    p = new;
    p.l = new;
    bad = 0;
    repeat (100) begin
      if (!p.randomize()) bad++;
      else if (!(p.l.x inside {[11:14]} && p.y == p.l.x + 1)) bad++;
    end
    $display("G2 bad=%0d", bad);

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
