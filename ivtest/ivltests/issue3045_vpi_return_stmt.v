// IEEE 1800-2023 37.78: a return statement is a vpiReturnStmt object. It was
// exposed as the vpiDisable it is lowered to, and a `return expr;` as a
// vpiBegin holding an assignment and that disable.
module top;
  logic go = 1;
  int result;

  function automatic int twice(input int x);
    if (x < 0) return 0;
    return x * 2;
  endfunction

  function automatic void note(input int x);
    if (x) return;
    $display("note");
  endfunction

  task automatic waiter;
    wait (go) $display("go");
    return;
  endtask

  // A real disable stays a vpiDisable.
  task stopper;
    begin : blk
      disable blk;
    end
  endtask

  initial begin
    $probe_return_stmt;
    result = twice(4);
    note(1);
    waiter;
    stopper;
    if (result !== 8) $display("FAILED: twice(4) = %0d", result);
    $finish;
  end
endmodule
