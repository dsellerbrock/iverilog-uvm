// R21: $stacktrace was completely undefined -- Icarus rejected it at
// runtime with "Error: System task/function $stacktrace() is not defined
// by any module." This pins that a task calling $stacktrace now compiles,
// runs, and lets simulation continue normally afterward.
//
// IEEE 1800-2023 20.17.2 standardizes $stacktrace as a no-argument task
// and string function. The task prints implementation-defined call-stack
// information; the paired function regression checks the string form.
//
// The printed format (one "  #<depth> <scope> (<location>)" line per
// frame, innermost first -- see vvp/vthread.cc:vpip_print_stacktrace())
// is free-form by design (the LRM mandates no specific format even where
// $stacktrace IS implemented by a vendor), so this test does not gold-
// match it. Instead it exercises three shapes that stress the call-frame
// walk -- directly in an initial block, one level into a task, and two
// levels into nested tasks -- and simply confirms none of them disturb
// the rest of simulation.

module main;

  task inner();
    $stacktrace;
  endtask

  task outer();
    inner();
  endtask

  initial begin
    // Called with no enclosing task -- frame 0 is the initial block itself.
    $stacktrace;

    // Called from one task deep.
    inner();

    // Called from two tasks deep.
    outer();

    $display("PASSED");
    $finish(0);
  end

endmodule
