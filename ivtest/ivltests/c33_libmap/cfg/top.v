// IEEE 1800-2023 33.6.1: with no configuration, an instance binds to the
// cell of the first library in the search order that has one. ADDER and M
// name the libraries the test expects (default: the map's declaration order).
// A test of a config (33.6.2 to 33.6.5) gives the library of each instance
// in EXP: a1, a1.f1, a1.f2, a2, a2.f1, a2.f2.
`ifndef ADDER
 `define ADDER "aLib"
 `define M "rtlLib"
`endif
`ifndef EXP
 `define EXP $sformatf("%0s/%0s/%0s/%0s/%0s/%0s", `ADDER, `M, `M, `ADDER, `M, `M)
`endif
module top;
   integer cells = 0;
   string  bound, expected;
   adder a1();
   adder a2();
   initial begin
      #1;
      bound = $sformatf("%0s/%0s/%0s/%0s/%0s/%0s", a1.lib, a1.f1.lib, a1.f2.lib,
			a2.lib, a2.f1.lib, a2.f2.lib);
      expected = `EXP;
      if (bound != expected)
	$display("FAILED: bound %s, expected %s", bound, expected);
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
