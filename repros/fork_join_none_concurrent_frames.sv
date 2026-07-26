module top;
  int fails = 0, o1 = -1, o2 = -1;
  function automatic void bump(ref int x); x = x + 5; endfunction
  task automatic tick(ref int x, input int n); repeat (n) #1 x++; endtask

  // two concurrent frames of one task, each with its own automatic
  // local as the ref actual. The worker is JOINED, so the frame
  // outlives the binding.
  task automatic conc(input int n, input int who);
    int loc = 0;
    tick(loc, n);
    if (who == 1) o1 = loc; else o2 = loc;
  endtask

  initial begin
    fork conc(3, 1); join_none
    fork conc(7, 2); join_none
    #12;
    if (o1 !== 3) begin fails++; $display("FAILED frame 1: %0d want 3", o1); end
    if (o2 !== 7) begin fails++; $display("FAILED frame 2: %0d want 7", o2); end
    if (fails == 0) $display("PASSED");
    $finish(0);
  end
endmodule
