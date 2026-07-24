// Pure SV, no DPI: is concurrent invocation of a STATIC task supposed to
// alias its formals? IEEE 1800-2017 13.3.1 says yes -- static lifetime
// means one copy of the arguments, shared by all invocations.
module top;
  task sv_wait(input int d, input int id);
    $display("  [%0t] static enter id=%0d d=%0d", $time, id, d);
    #(d);
    $display("  [%0t] static exit  id=%0d d=%0d", $time, id, d);
  endtask
  task automatic sv_wait_a(input int d, input int id);
    $display("  [%0t] auto   enter id=%0d d=%0d", $time, id, d);
    #(d);
    $display("  [%0t] auto   exit  id=%0d d=%0d", $time, id, d);
  endtask
  initial begin
    fork sv_wait(5,0); sv_wait(3,1); join
    $display("[%0t] static join", $time);
    fork sv_wait_a(5,0); sv_wait_a(3,1); join
    $display("[%0t] auto join", $time);
    $finish(0);
  end
endmodule
