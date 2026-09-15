package abi_qualified_enum_pkg;
  typedef enum bit [1:0] { A=0, B=1, C=2 } state_t;
  class holder;
    state_t e;
  endclass
  holder obj;
endpackage

class abi_qualified_enum_next;
  rand abi_qualified_enum_pkg::state_t value;
  rand abi_qualified_enum_pkg::state_t next_counted;
  rand abi_qualified_enum_pkg::state_t prev_counted;
  rand int count;
  bit fail;
  constraint c {
    count == 2;
    value == abi_qualified_enum_pkg::obj.e.next();
    next_counted == abi_qualified_enum_pkg::obj.e.next(count);
    prev_counted == abi_qualified_enum_pkg::obj.e.prev(count);
    fail -> abi_qualified_enum_pkg::obj.e.prev() == abi_qualified_enum_pkg::C;
  }
endclass

module test;
  import abi_qualified_enum_pkg::*;
  abi_qualified_enum_next item;
  initial begin
    obj = new;
    obj.e = A;
    item = new;
    item.fail = 0;
    item.count = 99;
    if (!item.randomize() || item.value != B || item.count != 2
        || item.next_counted != C || item.prev_counted != B)
      $fatal(1, "qualified enum next initial state/count priority");
    obj.e = B;
    item.count = 99;
    if (!item.randomize() || item.value != C || item.count != 2
        || item.next_counted != A || item.prev_counted != C)
      $fatal(1, "qualified enum next changed state/count priority");
    item.fail = 1;
    if (item.randomize() || item.value != C || item.count != 2
        || item.next_counted != A || item.prev_counted != C)
      $fatal(1, "qualified enum next unsat/rollback");
    $display("PASSED");
  end
endmodule
