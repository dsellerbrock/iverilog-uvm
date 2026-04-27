// Phase 13: program blocks. iverilog already parses program/endprogram
// as module-equivalent. Verify they elaborate and run.
program test;
   bit pass;
   initial begin
      pass = 1;
      $display("PROGRAM BLOCK TEST: PASS");
      $finish;
   end
endprogram
