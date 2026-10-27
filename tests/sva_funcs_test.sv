// IEEE 1800-2017 16.9.3 requires a clocking event for sampled-value
// functions; this edge-triggered process supplies one (16.14.6).
module top;
   logic clk = 0;
   logic sig = 0;
   int tick = 0;
   int errors = 0;

   always #5 clk = ~clk;

   task automatic check(input string what, input logic got, input logic want);
      if (got !== want) begin
         $display("FAIL %s: got %0b want %0b", what, got, want);
         errors++;
      end
   endtask

   always @(posedge clk) begin
      tick++;
      case (tick)
         2: begin
            check("rose",   $rose(sig),   1'b1);
            check("fell",   $fell(sig),   1'b0);
            check("stable", $stable(sig), 1'b0);
            check("past",   $past(sig),   1'b0);
         end
         3: begin
            check("rose",   $rose(sig),   1'b0);
            check("fell",   $fell(sig),   1'b0);
            check("stable", $stable(sig), 1'b1);
            check("past",   $past(sig),   1'b1);
         end
         4: begin
            check("rose",   $rose(sig),   1'b0);
            check("fell",   $fell(sig),   1'b1);
            check("stable", $stable(sig), 1'b0);
            check("past",   $past(sig),   1'b1);
         end
      endcase
   end

   initial begin
      @(negedge clk); sig = 1;
      @(negedge clk);
      @(negedge clk); sig = 0;
      @(negedge clk);
      if (tick != 4) begin
         $display("FAIL saw %0d samples, want 4", tick);
         errors++;
      end
      if (errors == 0) $display("SVA FUNCS TEST: PASS");
      else             $display("SVA FUNCS TEST: FAIL (%0d errors)", errors);
      $finish;
   end
endmodule
