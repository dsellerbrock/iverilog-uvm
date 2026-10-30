module issue1577_legacy;
  import "DPI" shared = function int f(input int x);
endmodule

module issue1577_current;
  import "DPI-C" shared = function int g(input int x);
endmodule

module issue1577_top;
  issue1577_legacy u1();
  issue1577_current u2();
endmodule
