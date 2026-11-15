// IEEE 1800-2023 33.4, 33.5.4: a config in the source files makes the cell
// of its design statement the top-level cell and binds top.u to alt, which
// nothing instantiates by name. With -s top no config is selected and u is
// the default leaf.
`ifndef BOUND
 `define BOUND "alt"
`endif
config cfg;
   design work.top;
   default liblist work;
   instance top.u use work.alt;
endconfig

module top;
   leaf u();
   initial begin
      #1;
      if (u.id !== `BOUND)
	$display("FAILED: top.u is %0s", u.id);
      else
	$display("PASSED");
   end
endmodule

module leaf;
   wire [31:0] id = "leaf";
endmodule

module alt;
   wire [31:0] id = "alt";
   // Not a root: with the config selected only its design cell is.
   initial if ($sformatf("%m") == "alt") $display("FAILED: alt is a root");
endmodule
