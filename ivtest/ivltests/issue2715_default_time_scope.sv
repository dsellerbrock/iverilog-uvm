// IEEE 1800-2023 13.5.3: a default argument is evaluated in the scope
// containing the subroutine declaration, each time a call uses it. So
// $time/$stime/$realtime in a default use the declaring scope's time unit,
// not the caller's.
`timescale 10ns/1ns
package p;
  function automatic time pt(input time d = $time); return d; endfunction
endpackage

`timescale 1us/1ns
module m;
  time td;
  task show(input time d = $time); td = d; endtask
  function automatic time ft(input time d = $time); return d; endfunction
  function automatic realtime fr(input realtime d = $realtime); return d; endfunction
  function automatic int unsigned fs(input int unsigned d = $stime); return d; endfunction
  function automatic time fx(input time d = $time + 1); return d; endfunction
  class c;
    function time get(input time d = $time); return d; endfunction
  endclass
  c obj = new;
endmodule

`timescale 1ns/1ps
module tb;
  m u();
  int errors = 0;
  function automatic time local_t(input time d = $time); return d; endfunction

  task check(input string what, input real got, input real exp);
    if (got != exp) begin
      $display("FAILED: %s = %0g, expected %0g", what, got, exp);
      errors++;
    end
  endtask

  initial begin
    #2500;                         // 2.5 us: integer forms round half up
    u.show();
    check("task default", u.td, 3);
    check("function default", u.ft(), 3);
    check("realtime default", u.fr(), 2.5);
    check("stime default", u.fs(), 3);
    check("expression default", u.fx(), 4);
    check("class method default", u.obj.get(), 3);
    check("package default", p::pt(), 250);
    check("caller-scope default", local_t(), 2500);
    check("explicit argument", u.ft($time), 2500);
    #1900;                         // 4.4 us rounds down
    check("rounded-down default", u.ft(), 4);
    check("rounded-down realtime", u.fr(), 4.4);
    if (errors == 0) $display("PASSED");
  end
endmodule
