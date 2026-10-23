// IEEE 1800-2017/2023 10.9.2: structure defaults descend into arrays.
module test;
  typedef struct { int x; int y[2]; } T;
  T t;

  initial begin
    t = '{default:5};
    $display("%0d %0d %0d", t.x, t.y[0], t.y[1]);
    t = '{x:1, default:6};
    $display("%0d %0d %0d", t.x, t.y[0], t.y[1]);
  end
endmodule
