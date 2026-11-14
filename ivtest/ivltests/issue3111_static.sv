package issue3111_pkg;
  typedef int I;
  class C #(type T = int, int N = 1);
    static int n = 0;
    T x;
  endclass
  class D #(type T = int, type U = int);
    static int n = 0;
  endclass
endpackage

module issue3111_static;
  issue3111_pkg::C a;
  issue3111_pkg::C#(issue3111_pkg::I, 1) b;
  issue3111_pkg::C#(.N(1), .T(int)) d;
  issue3111_pkg::C#(int, 2) c;
  issue3111_pkg::C#(bit [31:0], 1) e;
  issue3111_pkg::D#(issue3111_pkg::I, int) f;
  issue3111_pkg::D g;
  initial begin
    a = new; b = new; c = new; d = new; e = new; f = new; g = new;
    a.n = 7; c.n = 9; e.n = 11; f.n = 13;
    b = a;
    if (a.n !== 7 || b.n !== 7 || d.n !== 7 || c.n !== 9 || e.n !== 11 || g.n !== 13)
      $display("FAIL a=%0d b=%0d d=%0d c=%0d e=%0d g=%0d", a.n, b.n, d.n, c.n, e.n, g.n);
    else
      $display("PASS");
  end
endmodule
