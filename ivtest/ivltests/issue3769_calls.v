longint unit_trace;

package provider;
  task automatic imported_task(output int result);
    result = 17;
  endtask

  function automatic int imported_function();
    return 23;
  endfunction
endpackage

package caller;
  import provider::imported_task;
  import provider::imported_function;

  task automatic shadowed_task(output int result);
    result = 31;
  endtask

  task automatic check_bindings();
    int result;
    imported_task(result);
    if (result !== 17 || imported_function() !== 23)
      $fatal(1, "Wrong imported subroutine binding");
    shadowed_task(result);
    if (result !== 31)
      $fatal(1, "Wrong package-local subroutine binding");
  endtask

`ifndef ISSUE3769_LEGAL
  class worker #(parameter int digit = 2);
    task automatic run();
      $unit::unit_task(digit);
      $unit::unit_void(4);
      if (unit_value(5) !== 15)
        $fatal(1, "Wrong return from bare unit function call");
      if ($unit::unit_value(6) !== 16)
        $fatal(1, "Wrong return from qualified unit function call");
      void'($unit::unit_value(7));
    endtask
  endclass

  task automatic call_unit();
    worker #(2) w = new;
    worker #(8) v = new;
    unit_quick();
    unit_void(3);
    w.run();
    v.run();
  endtask
`endif
endpackage

module test;
  initial begin
    // Forward lookup from outside a package is legal in both forms.
    unit_task(8);
    if ($unit::unit_value(9) !== 19 || unit_trace !== 89)
      $fatal(1, "Wrong forward unit subroutine binding");
    unit_trace = 0;

    caller::check_bindings();
`ifndef ISSUE3769_LEGAL
    caller::call_unit();
    if (unit_trace !== 64'd132456784567)
      $fatal(1, "Wrong unit subroutine side effects: %0d", unit_trace);
`endif
    $display("PASSED");
  end
endmodule

task unit_quick();
  unit_trace = unit_trace * 10 + 1;
endtask

task automatic unit_task(input int digit);
  unit_trace = unit_trace * 10 + digit;
endtask

function automatic void unit_void(input int digit);
  unit_trace = unit_trace * 10 + digit;
endfunction

function automatic int unit_value(input int digit);
  unit_trace = unit_trace * 10 + digit;
  return digit + 10;
endfunction

task automatic shadowed_task(output int result);
  result = -1;
endtask
