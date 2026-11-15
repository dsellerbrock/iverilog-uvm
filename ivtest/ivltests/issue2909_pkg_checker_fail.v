// Only a checker can be instantiated through a package scope (17.3).
package issue2909_q;
  checker c(logic a);
  endchecker
endpackage

module issue2909_pkg_checker_fail;
  logic a;
  issue2909_q::d u1(a);
endmodule
