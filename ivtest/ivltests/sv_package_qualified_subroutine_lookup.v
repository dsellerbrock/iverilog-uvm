package existing_pkg;
  int calls;

  task caller;
    later();
  endtask

  task self_qualified_caller;
    existing_pkg::later();
  endtask

  task later;
    calls++;
  endtask

  function void bump;
    calls++;
  endfunction

  function int value;
    calls++;
    return calls;
  endfunction
endpackage

package origin_pkg;
  int calls;
  task bump;
    calls++;
  endtask
  function void bump_fn;
    calls++;
  endfunction
endpackage

package export_pkg;
  import origin_pkg::bump;
  import origin_pkg::bump_fn;
  export origin_pkg::*;
endpackage

module test;
  initial begin
    existing_pkg::caller();
    existing_pkg::self_qualified_caller();
    existing_pkg::bump();
    existing_pkg::value();
    export_pkg::bump();
    export_pkg::bump_fn();
    if (existing_pkg::calls != 4)
      $fatal(1, "package subroutine calls=%0d", existing_pkg::calls);
    if (origin_pkg::calls != 2)
      $fatal(1, "exported package subroutine calls=%0d", origin_pkg::calls);
    $display("PASSED");
  end
endmodule
