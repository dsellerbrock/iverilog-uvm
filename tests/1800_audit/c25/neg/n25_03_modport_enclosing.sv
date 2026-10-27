interface i;
  wire x, y;
  interface ill;
    wire a, b;
    modport master(input a, x, output b, y);
  endinterface
endinterface
module t; endmodule
