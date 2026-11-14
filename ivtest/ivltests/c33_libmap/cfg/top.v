// IEEE 1800-2023 33.6.1: with no configuration, an instance binds to the
// cell of the first library in the search order that has one. ADDER and M
// name the libraries the test expects (default: the map's declaration order).
`ifndef ADDER
 `define ADDER "aLib"
 `define M "rtlLib"
`endif
module top;
   integer cells = 0;
   adder a1();
   adder a2();
   initial begin
      #1;
      if (a1.lib !== `ADDER || a2.lib !== `ADDER)
	$display("FAILED: adder bound to %0s", a1.lib);
      else if (a1.f1.lib !== `M || a2.f2.lib !== `M)
	$display("FAILED: m bound to %0s", a1.f1.lib);
      // Only top is a root: the unbound same-named cells are not elaborated.
      else if (cells !== 6)
	$display("FAILED: %0d cells elaborated, expected 6", cells);
      else
	$display("PASSED");
   end
endmodule

module m;
   wire [63:0] lib = "rtlLib";
   initial top.cells = top.cells + 1;
endmodule
