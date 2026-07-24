// M14/M9-9 negative: checker DECLARATIONS are now supported (they ride
// the module machinery; see sv_checker_basic), but a checker declared
// NESTED inside a module cannot yet be instantiated (nested definition
// scoping is the same limitation as nested modules). That gap must
// stay a loud diagnostic, never a silently-dropped instance.
module top;
  logic clk=0, a=1;
  checker my_chk(input logic c, logic x);
    assert property (@(posedge c) x);
  endchecker
  my_chk u1(clk, a);
  initial $finish(0);
endmodule
