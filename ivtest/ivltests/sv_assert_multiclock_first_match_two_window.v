module sv_assert_multiclock_first_match_two_window;
 bit c1=0,c2=0,a=0,b=0,c=0,good=0; int fails=0;
 always #10 c1=~c1;
 initial begin #15 c2=1; forever #20 c2=~c2; end // posedges15,55,95
 ap: assert property (@(posedge c1) first_match(a ##[1:2] b ##[1:2] c) |-> @(posedge c2) good)
   else begin fails++; $display("FAIL %0t",$time); end
 initial begin
  #9 a=1; #2 a=0;
  #18 b=1; // before c1=30
  #20 c=1; // before c1=50, the earliest endpoint
  #12 good=1; // after failing c2=55, before later c2=95
  #38;
  if(fails!=1)$fatal(1,"fails=%0d",fails);
  $display("PASSED");$finish(0);
 end
endmodule
