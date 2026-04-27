// Simpler clocking test — just check that direct interface access works.
interface bus_if(input clk);
   logic data;
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
      #2;
      bif.data = 1;
      if (bif.data !== 1) begin $display("FAIL"); pass = 0; end
      if (pass) $display("INTERFACE BASIC: PASS");
      else      $display("INTERFACE BASIC: FAIL");
      $finish;
   end
endmodule
