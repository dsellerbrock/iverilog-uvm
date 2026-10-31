class C;
  rand int v;
endclass

module tb;
  C c;
  logic [3:0] s;
  logic [3:0] a[2];
  int ok1, ok2;

  initial begin
    c = new;
    s = 4'bx;
    a[0] = 4'bx;
    a[1] = 4'bx;
    ok1 = c.randomize() with { v == 0 || s == 7; };
    ok2 = c.randomize() with { v == 0 || a[0] == 7; };
    $display("scalar x: %0d  element x: %0d", ok1, ok2);
  end
endmodule
