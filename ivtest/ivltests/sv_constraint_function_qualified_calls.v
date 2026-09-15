// Qualified package and class-static functions in class constraints.
package abi_qualified_pkg;
  // Package functions have static lifetime by default. This function retains
  // no state: its result depends only on the current input value.
  function int plus_one(input int value);
    return value + 1;
  endfunction
  function int one();
    return 1;
  endfunction
endpackage

class abi_qualified_util;
  static function automatic int twice(input int value);
    return value * 2;
  endfunction
endclass

class abi_qualified_ok;
  rand int x;
  rand int y;
  bit fail;
  constraint c {
    y == 4;
    x == abi_qualified_pkg::plus_one(y);
    x + abi_qualified_util::twice(y) == 13;
    fail -> abi_qualified_pkg::one() == 2;
  }
endclass

class abi_qualified_unsat;
  rand int x;
  constraint c { x == 7; abi_qualified_pkg::one() == 2; }
endclass

module test;
  abi_qualified_ok ok;
  abi_qualified_unsat bad;
  initial begin
    ok = new;
    ok.x = 31;
    ok.y = 32;
    ok.fail = 0;
    if (!ok.randomize() || ok.x != 5 || ok.y != 4)
      $fatal(1, "qualified function success");
    ok.fail = 1;
    if (ok.randomize() || ok.x != 5 || ok.y != 4)
      $fatal(1, "qualified function late unsat/rollback");
    ok.fail = 0;
    ok.x = 31;
    ok.y = 32;
    if (!ok.randomize() || ok.x != 5 || ok.y != 4)
      $fatal(1, "qualified function repeat success");

    bad = new;
    bad.x = 42;
    if (bad.randomize() || bad.x != 42)
      $fatal(1, "qualified function unsat/rollback");
    $display("PASSED");
  end
endmodule
