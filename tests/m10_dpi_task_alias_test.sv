// M10: DPI import tasks and c_identifier alias binding (35.4).
// Pre-M10 the task form was a syntax error and the alias form was
// unparseable, so UVM-style `import "DPI-C" foo_c = function ...`
// declarations could not compile.
module m10_dpi_task_alias_test;

  // Imported task (context property allowed, no return value).
  import "DPI-C" context task c_log_event(int code, string tag);
  import "DPI-C" task c_accumulate(int delta);

  // Alias forms: the SV name differs from the C symbol.
  import "DPI-C" c_get_accum = function int sv_get_accumulated();
  import "DPI-C" c_scale_add = function real sv_scale(real x, int k);
  import "DPI-C" c_tick = task sv_tick();

  int pass_count = 0;
  int fail_count = 0;

  task check(input string name, input bit ok);
    if (ok) pass_count++;
    else begin
      fail_count++;
      $display("FAIL: %s", name);
    end
  endtask

  int v;
  real r;

  initial begin
    // Task calls with mixed args.
    c_log_event(1, "alpha");
    c_log_event(2, "beta");
    c_accumulate(10);
    c_accumulate(32);

    // Alias-bound function reads back state mutated by the tasks:
    // proves both directions went through the real C symbols.
    v = sv_get_accumulated();
    check("task_accum_alias", v == 42 + 2); // +2 log events

    r = sv_scale(1.5, 4);
    check("alias_mixed", r == 6.0);

    sv_tick();
    sv_tick();
    sv_tick();
    v = sv_get_accumulated();
    check("task_alias_tick", v == 44 + 3);

    if (fail_count == 0)
      $display("M10 DPI TASK/ALIAS TEST: PASS (%0d/%0d)", pass_count, pass_count);
    else
      $display("M10 DPI TASK/ALIAS TEST: FAIL (%0d passed, %0d failed)",
               pass_count, fail_count);
    $finish(0);
  end
endmodule
