// Phase 13: clocking blocks. Verify basic compile + that @(cb) waits for
// the clocking event and cb.sig accesses work.
// M8-2a update: input clockvars now have real sampled semantics
// (IEEE 1800-2017 14.13). cb.data reads the value sampled at the most
// recent clocking event, and the sample updates AFTER the Active
// region of the edge time step -- so a process that wakes on the raw
// @(posedge clk) still reads the PREVIOUS sample. Wait on @(cb) to
// observe the new edge's sample (this is the LRM-recommended pattern
// precisely because the raw-edge read is a race in real simulators).
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
      @(bif.cb);
      // After the clocking event, ack should reflect what we drove.
      if (bif.ack !== 1) begin $display("FAIL: ack=%0b", bif.ack); pass = 0; end
      // Read input via clocking block: @(bif.cb) resumed after this
      // edge's input sampling, so cb.data is the newly sampled 1.
      if (bif.cb.data !== 1) begin $display("FAIL: cb.data=%0b", bif.cb.data); pass = 0; end

      if (pass) $display("CLOCKING TEST: PASS");
      else      $display("CLOCKING TEST: FAIL");
      $finish;
   end
endmodule
