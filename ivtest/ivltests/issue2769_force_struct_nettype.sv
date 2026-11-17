// IEEE 1800-2023 6.6.7: "A force statement can override the value of a net
// of a user-defined nettype. When released, the net returns to the resolved
// value." (ruling on #2769). While forced, the struct net follows its
// source (whole and member stores) and ignores its own driver.
module t;
  typedef struct { int a; logic [3:0] b; } st_t;
  nettype st_t ns;
  st_t v1, v2;
  ns f;
  assign f = v1;
  initial begin
    v1.a = 1; v1.b = 4'h2; v2.a = 7; v2.b = 4'h8;
    #1 $display("1 f=%0d %h (driven)", f.a, f.b);
    force f = v2;
    #1 $display("2 f=%0d %h (forced to v2)", f.a, f.b);
    v2.a = 8;
    #1 $display("3 f=%0d (tracks v2 member store)", f.a);
    v1.a = 3;
    #1 $display("4 f=%0d (driver change ignored)", f.a);
    v2 = v1;
    #1 $display("5 f=%0d %h (tracks whole store to v2)", f.a, f.b);
    release f;
    #1 $display("6 f=%0d %h (released: driven value)", f.a, f.b);
    v1.a = 4;
    #1 $display("7 f=%0d (driven again)", f.a);
  end
endmodule
