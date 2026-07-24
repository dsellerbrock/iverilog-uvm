// M10-4 follow-on: the frame allocated for an automatic DPI export must
// nest correctly with the frames of automatic subroutines the exported
// body itself calls, and must survive a delay taken after those calls.
//
// The export dispatcher allocates the export's frame directly rather than
// going through the %alloc opcode, so it is worth pinning that the frame
// still behaves like an ordinary automatic frame once the body starts
// pushing its own: the export owns exactly its own frame (freed when its
// thread is reaped) and nested %alloc/%free inside the body must neither
// free it early nor leak.
//
// Three concurrent invocations, each of which calls an automatic task that
// calls an automatic function, then delays. Each must keep its own
// arguments across all of it.
module m10i_dpi_export_automatic_nested_test;
  import "DPI-C" context task c_go(input int d, input int id);

  int seen[3];
  int deep[3];
  int errors = 0;

  function automatic int helper(int v);
    return v * 10;
  endfunction

  task automatic inner(input int v, input int id);
    #1 deep[id] = helper(v);
  endtask

  task automatic sv_outer(input int d, input int id);
    seen[id] = d;
    inner(d, id);          // nested automatic frames inside the export
    #(d);
    // The export's own frame must be intact after the nested calls
    // pushed and popped frames of their own, and after the delay.
    if (seen[id] != d) begin
      $display("FAIL export frame clobbered: id=%0d saw %0d, expected %0d",
               id, seen[id], d);
      errors++;
    end
  endtask
  export "DPI-C" task sv_outer;

  initial begin
    for (int i = 0; i < 3; i++) begin
      seen[i] = -1;
      deep[i] = -1;
    end

    fork
      c_go(2, 0);
      c_go(4, 1);
      c_go(6, 2);
    join

    if (seen[0] != 2 || seen[1] != 4 || seen[2] != 6) begin
      $display("FAIL arguments aliased across frames: %0d, %0d, %0d; expected 2, 4, 6",
               seen[0], seen[1], seen[2]);
      errors++;
    end
    if (deep[0] != 20 || deep[1] != 40 || deep[2] != 60) begin
      $display("FAIL nested call results: %0d, %0d, %0d; expected 20, 40, 60",
               deep[0], deep[1], deep[2]);
      errors++;
    end
    // Each invocation takes 1 tick in inner() then its own d: 3, 5 and 7.
    if ($time != 7) begin
      $display("FAIL join time: t=%0t, expected 7", $time);
      errors++;
    end

    if (errors == 0) $display("PASS m10i_dpi_export_automatic_nested_test");
    $finish(0);
  end
endmodule
