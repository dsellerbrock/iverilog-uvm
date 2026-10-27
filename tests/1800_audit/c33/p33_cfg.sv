config cfg;
  design work.top;
  default liblist work;
  instance top.u use work.alt;
endconfig
module top; leaf u(); endmodule
module leaf; initial $display("LEAF"); endmodule
module alt;  initial $display("ALT");  endmodule
