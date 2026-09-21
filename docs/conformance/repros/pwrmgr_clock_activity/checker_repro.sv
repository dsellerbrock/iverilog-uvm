module checker_repro;
 timeunit 1ps; timeprecision 1ps;
 parameter integer RUN=1, START=12, HALF=20, LEVEL=0, CYCLES=139;
 parameter integer RESPONSE=0, LC_N=1, ENABLE_AT=0, ENABLED=1, DISABLE_AT=0, EXPECT_FAILURES=0;
 bit clk=0, esc=LEVEL, en=ENABLED && ENABLE_AT==0, disable_prop=0;
 time esc_clk_last_edge=0;
 integer failures=0,edges=0,samples=0;
 always #20 clk=~clk;
 initial if(RUN) begin #(START);esc=~esc;forever #(HALF) esc=~esc;end
 initial if(ENABLE_AT) begin #(ENABLE_AT);en=ENABLED;end
 initial if(DISABLE_AT) begin #(DISABLE_AT);disable_prop=1;end
 always @(posedge esc) begin esc_clk_last_edge=$time; edges++;end
 always @(negedge clk) samples++;
 a: assert property (@(posedge !clk) disable iff(disable_prop !== '0)
     ($stable(esc_clk_last_edge) && en)[*138] |=> RESPONSE || !LC_N)
   else begin failures++; $display("CHECK_FAILURE sample=%0d time=%0t",samples,$time);end
 initial begin
   #(CYCLES*40+1);
   if(failures!=EXPECT_FAILURES) $fatal(1,"failures=%0d expected=%0d",failures,EXPECT_FAILURES);
   if(RUN && START<CYCLES*40 && edges==0) $fatal(1,"no actual clock activity");
   $display("PASS samples=%0d edges=%0d failures=%0d",samples,edges,failures);$finish(0);
 end
endmodule
