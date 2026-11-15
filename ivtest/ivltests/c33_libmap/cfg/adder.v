// rtl adder
module adder;
   wire [63:0] lib = "aLib";
   m f1();
   m f2();
   initial top.cells = top.cells + 1;
endmodule

module m;
   wire [63:0] lib = "aLib";
   initial top.cells = top.cells + 1;
endmodule
