// IEEE 1800-2023 10.6.2, ruling on #2769: a singular member of an unpacked
// struct variable is a legal force target. While forced it follows its
// source and ignores stores, a whole struct store keeps it, and after
// release it keeps its value until the next assignment.
module t;
  typedef struct { int a; logic [3:0] b; real r; } S2;
  S2 v, f;
  int x = 10;
  real y = 1.5;
  initial begin
    v.a = 1; v.b = 4'h2; v.r = 0.5;
    force v.a = x;
    force v.r = y;
    #1 $display("1 a=%0d b=%h r=%0.2f", v.a, v.b, v.r);
    x = 11; y = 2.5;
    #1 $display("2 a=%0d r=%0.2f (tracks source)", v.a, v.r);
    v.a = 99; v.b = 4'h7;
    #1 $display("3 a=%0d b=%h (store to a ignored, b written)", v.a, v.b);
    f.a = 5; f.b = 4'h9; f.r = 9.0;
    v = f;
    #1 $display("4 a=%0d b=%h r=%0.2f (whole store keeps forced members)", v.a, v.b, v.r);
    release v.a;
    x = 12;
    #1 $display("5 a=%0d (released: keeps value, no longer tracks)", v.a);
    v.a = 7;
    #1 $display("6 a=%0d (writable again)", v.a);
    force v.b = 4'hc;
    v.b = 4'h1;
    #1 $display("7 b=%h (constant force)", v.b);
    release v.b; release v.r;
    v.b = 4'h3; v.r = 3.25;
    #1 $display("8 b=%h r=%0.2f", v.b, v.r);
  end
endmodule
