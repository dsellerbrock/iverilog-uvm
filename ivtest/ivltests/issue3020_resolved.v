interface class A; parameter int X = 1; endclass
interface class B; parameter int X = 1; endclass
interface class C extends A, B; parameter int X = 2; endclass
interface class D extends C; endclass
interface class E extends C; endclass
interface class F extends D, E; endclass
interface class T extends A, B; typedef int X; endclass
module test;
  initial begin
    if (C::X != 2) $fatal(1, "local override failed");
    $display("PASS");
  end
endmodule
