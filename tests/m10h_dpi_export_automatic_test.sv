// M10-4: DPI export with AUTOMATIC lifetime (IEEE 1800-2017 35.5 + 13.3.1).
//
// An automatic subroutine gets a fresh frame per invocation, so its formal
// arguments live in that frame, not in the scope's static storage. The
// export dispatcher marshaled C arguments straight into the static
// prototype nets that the :export_dpi directive names -- storage an
// automatic body never reads. Every argument silently arrived as x: a
// value-returning export returned garbage and `#(d)` with d==x degenerated
// to a zero delay, all with no diagnostic. It was wrong even for a single,
// non-concurrent call.
//
// The dispatcher now allocates a context for an automatic export and
// marshals into it, which is the same thing %alloc does for an ordinary SV
// call. The child thread owns the frame and frees it when it is reaped.
//
// Checks here:
//   - a single automatic exported FUNCTION receives its argument and
//     returns the right value;
//   - a single automatic exported TASK receives its argument and actually
//     consumes that much time;
//   - two concurrent invocations of ONE automatic exported task each keep
//     their own arguments and finish at their own times -- the case that
//     motivates automatic lifetime in the first place.
//
// A STATIC exported task deliberately still shares one frame: 13.3.1 gives
// a static subroutine a single copy of its arguments, so concurrent
// invocations alias, exactly as a plain SV static task does. That is
// covered by m10_dpi_task_alias_test, not here.
module m10h_dpi_export_automatic_test;
  import "DPI-C" context function int  c_call_fn(input int v);
  import "DPI-C" context task          c_call_task(input int d, input int id);

  int  fn_arg_seen  = -1;
  int  done_at[3];
  int  arg_seen[3];
  int  ends = 0;

  function automatic int sv_auto_fn(int x);
    fn_arg_seen = x;
    return x + 1;
  endfunction
  export "DPI-C" function sv_auto_fn;

  task automatic sv_auto_task(input int d, input int id);
    arg_seen[id] = d;      // read before the delay
    #(d);
    done_at[id] = $time;   // and the frame must survive the delay
    ends++;
  endtask
  export "DPI-C" task sv_auto_task;

  initial begin
    int r;
    int errors = 0;

    for (int i = 0; i < 3; i++) begin
      done_at[i] = -1;
      arg_seen[i] = -1;
    end

    // 1. Single automatic exported function.
    r = c_call_fn(4);
    if (fn_arg_seen != 4) begin
      $display("FAIL auto function argument: saw %0d, expected 4", fn_arg_seen);
      errors++;
    end
    if (r != 5) begin
      $display("FAIL auto function return: got %0d, expected 5", r);
      errors++;
    end

    // 2. Single automatic exported task: must see d and consume d.
    c_call_task(6, 0);
    if (arg_seen[0] != 6) begin
      $display("FAIL auto task argument: saw %0d, expected 6", arg_seen[0]);
      errors++;
    end
    if ($time != 6) begin
      $display("FAIL auto task did not consume time: t=%0t, expected 6", $time);
      errors++;
    end
    if (done_at[0] != 6) begin
      $display("FAIL auto task done_at[0]=%0d, expected 6", done_at[0]);
      errors++;
    end

    // 3. Two concurrent invocations of the SAME automatic exported task.
    //    Each frame keeps its own d, so they finish 3 and 9 ticks later.
    fork
      c_call_task(3, 1);
      c_call_task(9, 2);
    join
    if (arg_seen[1] != 3 || arg_seen[2] != 9) begin
      $display("FAIL concurrent arguments aliased: saw %0d and %0d, expected 3 and 9",
               arg_seen[1], arg_seen[2]);
      errors++;
    end
    if (done_at[1] != 9 || done_at[2] != 15) begin
      $display("FAIL concurrent completion times: %0d and %0d, expected 9 and 15",
               done_at[1], done_at[2]);
      errors++;
    end
    if ($time != 15) begin
      $display("FAIL join time: t=%0t, expected 15", $time);
      errors++;
    end
    if (ends != 3) begin
      $display("FAIL task body ran %0d times, expected 3", ends);
      errors++;
    end

    if (errors == 0) $display("PASS m10h_dpi_export_automatic_test");
    $finish(0);
  end
endmodule
