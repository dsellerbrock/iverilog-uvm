// Regression for the task_nonansi_*2 / task_iotypes vendored-ivtest
// cluster: non-ANSI task/function port declarations intermixed with the
// declaration-section early exit. A leading variable-style declaration
// (e.g. `int x;` or `integer B;`) reduces out of the tf_item declaration
// section into statement context (same mechanism as the event-declaration
// bug), and a subsequent `input x;` / `output C;` had no statement rule —
// "syntax error / Malformed statement". statement_item now routes
// direction declarations back into the task-port machinery, and
// PTaskFunc::set_ports preserves declaration order when merging.
module task_nonansi_direction_test;

  // Type first, then direction (task_nonansi_int2 shape).
  task t1;
    int x;
    input x;
    output int y;
    y = x + 1;
  endtask

  // Direction first, then type redeclarations (task_iotypes shape).
  task t2;
    input  b;
    integer b;
    output c;
    integer c;
    begin
      c = b + 10;
    end
  endtask

  // Function variant.
  function f1;
    reg [7:0] acc;
    input [7:0] a;
    begin
      acc = a;
      f1 = acc[0];
    end
  endfunction

  int y;
  integer c;
  initial begin
    t1(41, y);
    t2(32'd5, c);
    if (y == 42 && c == 15 && f1(8'h03) == 1'b1)
      $display("PASS: non-ANSI directions after declaration-section exit");
    else
      $display("FAIL: y=%0d c=%0d f1=%b", y, c, f1(8'h03));
    $finish;
  end
endmodule
