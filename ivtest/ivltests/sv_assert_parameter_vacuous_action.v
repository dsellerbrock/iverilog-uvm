// IEEE 1800-2017/2023 16.12.7, 16.14.1: failed repetitions are
// vacuous only before their first matching length.
module vacuity_min_check #(parameter LO=3, HI=5)(input clk,keep);
 integer p=0,f=0;
 q: assert property (@(posedge clk) keep[*LO:HI] |-> 1'b1) p++; else f++;
 initial begin
  #25; if(p!=4 || f!=0) $fatal(1,"parameter p/f=%0d/%0d",p,f);
 end
endmodule
module vacuity_min_driver;
 reg clk=0,keep=0;
 vacuity_min_check dut(clk,keep);
 task tick; #5 clk=1; #1 clk=0; endtask
 initial begin
  tick(); keep=1; tick(); tick(); keep=0; tick();
  #2; ;
 end
endmodule

module vacuity_controls_check #(parameter LO=2, HI=4, ZERO=0)(input clk,keep,prefix);
 integer rp=0,rf=0,zp=0,zf=0,pp=0,pf=0,zref=0;
 r: assert property (@(posedge clk) keep[*LO:HI] |-> 1'b0) rp++; else rf++;
 z: assert property (@(posedge clk) keep[*ZERO] |=> ##[0:HI] 1'b1) zp++; else zf++;
 zr: assert property (@(posedge clk) 1'b0[*ZERO] |=> ##[0:HI] 1'b1) zref++; else zf++;
 p: assert property (@(posedge clk) prefix ##1 keep[*LO:HI] |-> 1'b1) pp++; else pf++;
 initial begin
  #25;
  // At the final false keep, only the new and one-step-old starts are
  // unmatched. Older starts already produced endpoints; no vacuity there.
  if(rp!=2 || rf==0) $fatal(1,"matched-age exclusion p/f=%0d/%0d",rp,rf);
  // Empty repetition must be independent of keep; false keep adds no vacuity.
  if(zp!=zref || zp==0 || zf!=0) $fatal(1,"empty repetition p/f=%0d/%0d",zp,zf);
  // Three false prefixes plus one prefix that dies before minimum length.
  if(pp!=4 || pf!=0) $fatal(1,"prefix p/f=%0d/%0d",pp,pf);
 end
endmodule
module vacuity_controls_driver;
 reg clk=0,keep=1,prefix=0;
 vacuity_controls_check dut(clk,keep,prefix);
 task tick; #5 clk=1; #1 clk=0; endtask
 initial begin
  tick(); prefix=1; tick(); prefix=0; tick(); keep=0; tick();
  #2; ;
 end
endmodule

module sv_assert_parameter_vacuous_action;
 vacuity_min_driver minimum();
 vacuity_controls_driver controls();
 initial begin #27; $display("PASSED"); end
endmodule
