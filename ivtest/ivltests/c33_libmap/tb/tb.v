// IEEE 1800-2023 33.8.3. Every file of ../lib defines a cell `who'; -L
// selects the library, and so shows which library each file was mapped to:
//   foobar.v  lib1 (wildcarded file name beats lib3's directory)
//   foo.v     lib2 (explicit file name beats lib1's wildcard)
//   bar.v     lib3 (directory)
//   barver.v  lib4 (wildcarded file name beats lib3's directory)
// This file matches no path specification and goes to `work'.
`ifndef WHO
 `define WHO "foobar"
`endif
module tb;
   who u();
   ord o();
   initial begin
      #1;
      if (u.file !== `WHO)
	$display("FAILED: who bound to %0s.v", u.file);
      // Declaration order with the include in place: lib2 before lib4.
      else if (o.file !== "foo" && `WHO != "barver")
	$display("FAILED: ord bound to %0s.v", o.file);
      else
	$display("PASSED");
   end
endmodule
