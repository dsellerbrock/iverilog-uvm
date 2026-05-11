// Regression: SystemVerilog `->>` (non-blocking event trigger) must
// actually wake `@event` waits, not silently sorry-out at tgt-vvp.
//
// Two waiters share one event:
//   - blocking-trigger arm uses `-> e1`  (sanity baseline)
//   - non-blocking arm uses `->> e2`     (the construct under test)
// Both must wake their waiters within the same simulation; if `->>`
// were dropped to a no-op the second waiter would hang to $finish.

module top();
   event e1, e2;
   int   woke1, woke2;

   initial begin
      woke1 = 0;
      woke2 = 0;
      fork
         begin
            @e1;
            woke1 = 1;
         end
         begin
            @e2;
            woke2 = 1;
         end
         begin
            #1 -> e1;
            #1 ->> e2;
         end
      join
      if (woke1 == 1 && woke2 == 1)
        $display("PASSED");
      else
        $display("FAILED woke1=%0d woke2=%0d", woke1, woke2);
      $finish;
   end
endmodule
