// IEEE 1800-2023 17.3: checker_instantiation names a ps_checker_identifier,
// [ package_scope ] checker_identifier, so a package checker is p::c.
package issue2909_p;
  typedef logic [3:0] nib_t;
  checker c(logic a, event clk);
    a1: assert property (@clk a) else $display("q08 fail at %0t", $time);
  endchecker
endpackage

module issue2909_pkg_checker;
  logic clk = 0, a = 1;
  issue2909_p::nib_t n = 4'h3;   // p::type declarations still parse
  always #5 clk = ~clk;
  issue2909_p::c u(a, posedge clk);
  initial begin #12 a = 0; #10 $display("q08 done n=%0d", n); $finish; end
endmodule
