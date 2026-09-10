// IEEE 1800-2017/2023 16.12.7 and 16.14.1: one user action per
// vacuous attempt; first failed sample resolves it, including simultaneous
// failures. Delayed action bodies cannot serialize subsequent attempts.
module test;
 reg clk=0,a=0,b=0,c=1;
 integer p=0,f=0, delayed=0;
 reg never=0;
 integer np=0,nf=0;
 nfa: assert property (@(posedge clk) never |-> not (b[*2])) np++; else nf++;
 for(genvar n=1;n<=3;n++) begin:G
  integer gp=0,gf=0;
  q: assert property (@(posedge clk) never |-> ##n c) gp++; else gf++;
  initial begin
   #55; if(gp!=5 || gf!=0) $fatal(1,"genvar=%0d p/f=%0d/%0d",n,gp,gf);
  end
 end
 q: assert property (@(posedge clk) a ##1 b |-> c) begin p++; #20 delayed++; end else f++;
 task tick;
  #5 clk=1; #1; clk=0;
 endtask
 initial begin
  // First failed start resolves immediately, without fake startup attempts.
  tick(); if(p!=1) $fatal(1,"first failure p=%0d",p);
  a=1; tick(); if(p!=1) $fatal(1,"pending p=%0d",p);
  // Prior start and new start fail together; delayed actions must not block.
  a=0; tick(); if(p!=3) $fatal(1,"two failures p=%0d",p);
  a=1; b=1; tick(); if(p!=3) $fatal(1,"pending2 p=%0d",p);
  a=0; tick(); if(p!=5 || f!=0) $fatal(1,"mixed p/f=%0d/%0d",p,f);
  #25; if(delayed!=5) $fatal(1,"delayed=%0d",delayed);
  #1; if(np!=5 || nf!=0) $fatal(1,"NFA p/f=%0d/%0d",np,nf);
  $display("PASSED");
 end
endmodule
