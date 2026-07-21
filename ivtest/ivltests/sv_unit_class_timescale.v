// $time / $realtime inside a class method declared at compilation-unit
// ($unit) scope must scale to the active `timescale, not to $unit's
// default 1 s (IEEE 1800-2017 3.14.2.3 / 20.3.1).
//
// A $unit-scope class has no enclosing module, so the runtime scope walk
// for the time system functions used to run all the way out to $unit
// (time unit = 1 s) and a stored $time scaled to 0. It must stop at the
// class/method scope, which inherits the file's `timescale.
//
// Prints PASSED only if every stored/returned time matches.

`timescale 1ns/1ps

class ubox;               // compilation-unit ($unit) scope
  time last;
  real rt;
  task grab();
    #7;
    last = $time;         // stored $time (the observable failure)
    rt   = $realtime;
  endtask
  function time echo();   // $time as a function return value
    return $time;
  endfunction
endclass

module sv_unit_class_timescale;
  time mt;
  task automatic mgrab(); #2; mt = $time; endtask   // module scope, control
  int errors = 0;

  initial begin
    ubox u;
    u = new;
    mgrab();              // module $time at t=2
    u.grab();             // class-method $time/$realtime at t=9

    if (u.last != 9) begin $display("FAIL ubox.last=%0d (want 9)", u.last); errors++; end
    if (u.rt   != 9) begin $display("FAIL ubox.rt=%0g (want 9)", u.rt);     errors++; end
    if (mt     != 2) begin $display("FAIL mt=%0d (want 2)", mt);            errors++; end
    if (u.echo() != 9) begin $display("FAIL echo=%0d (want 9)", u.echo()); errors++; end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish(0);
  end
endmodule
