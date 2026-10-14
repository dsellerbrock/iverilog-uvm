// R21: $stacktrace was completely undefined -- Icarus rejected it at
// runtime with "Error: System task/function $stacktrace() is not defined
// by any module." This pins that a task calling $stacktrace now compiles,
// runs, and lets simulation continue normally afterward.
//
// NOTE ON THE LRM CITATION: the roadmap item that motivated this cites
// IEEE 1800-2017 20.3.3, but that subclause is actually $realtime --
// clause 20's own severity/elaboration task lists (20.10, 20.11) name
// only $fatal/$error/$warning/$info, and $stacktrace does not appear
// anywhere in clause 20 of the 2017 LRM. It is a widely implemented
// vendor debug extension (e.g. Questa), not a standard SystemVerilog
// system task. With no LRM text to conform to, Icarus implements the
// common contract found elsewhere: a TASK (so it cannot be called as a
// function or used in an expression), taking no arguments, that prints
// the current call stack to stdout and does not itself affect
// simulation control flow.
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
