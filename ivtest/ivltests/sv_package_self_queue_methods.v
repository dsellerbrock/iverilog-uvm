// A package name is not entered in the global package table until endpackage.
// Self-qualified queue method calls inside that package must nevertheless be
// represented as package references, not class-static receiver expressions.
package self_queue_pkg;
  int values[$];

  function automatic void append(input int value);
    self_queue_pkg::values.push_back(value);
  endfunction

  function automatic int count();
    return self_queue_pkg::values.size();
  endfunction
endpackage

module main;
  import self_queue_pkg::*;

  initial begin
    self_queue_pkg::values.delete();
    append(7);
    self_queue_pkg::append(9);
    if (count() == 2
        && self_queue_pkg::values[0] == 7
        && self_queue_pkg::values[1] == 9)
      $display("PASSED");
    else
      $display("FAILED size=%0d values=%p",
               self_queue_pkg::values.size(), self_queue_pkg::values);
  end
endmodule
