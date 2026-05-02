// Phase 13: clocking blocks. Verify basic compile + that @(cb) waits for
// the clocking event and cb.sig accesses work.
interface bus_if(input clk);
   logic data;
   logic ack;

   clocking cb @(posedge clk);
      input  data;
      output ack;
   endclocking
endinterface

module top;
   bit clk;
   bus_if bif(clk);
   bit pass;

   initial clk = 0;
   always #5 clk = ~clk;

   initial begin
      pass = 1;
      bif.data = 0;
      bif.ack  = 0;
      #2;
      // Wait one clock edge through the clocking block
      @(bif.cb);
      bif.data = 1;
      // Drive an output via the clocking block — semantics may be relaxed.
      bif.cb.ack <= 1;
      @(posedge clk);
      // After the clock edge, ack should reflect what we drove.
      if (bif.ack !== 1) begin $display("FAIL: ack=%0b", bif.ack); pass = 0; end
      // Read input via clocking block (samples upstream signal).
      if (bif.cb.data !== 1) begin $display("FAIL: cb.data=%0b", bif.cb.data); pass = 0; end

      if (pass) $display("CLOCKING TEST: PASS");
      else      $display("CLOCKING TEST: FAIL");
      $finish;
   end
endmodule
