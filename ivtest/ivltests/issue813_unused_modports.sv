interface outer;
  wire x;
  interface inner;
    wire a;
    modport m(input a, x);
  endinterface
endinterface
interface unused;
  wire a;
  modport m(input b);
endinterface
module issue813_top;
endmodule
