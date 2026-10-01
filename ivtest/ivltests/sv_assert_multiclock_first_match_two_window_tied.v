module sv_assert_multiclock_first_match_two_window_tied;
 bit c1=0,c2=0,a=0,b=0,c=0,good=1;int covers=0,fails=0;
 always #10 c1=~c1; initial begin #15 c2=1;forever #10 c2=~c2;end
 cp: cover property(@(posedge c1) first_match(a##[1:2]b##[1:2]c)|->@(posedge c2)good) covers++;
 ap: assert property(@(posedge c1) first_match(a##[1:2]b##[1:2]c)|->@(posedge c2)good) else fails++;
 initial begin #9 a=1;#2 a=0;$assertoff(0);#18 b=1;#40 c=1;#2 c=0;#10;
  if(covers!=1||fails!=0)$fatal(1,"covers=%0d fails=%0d",covers,fails);$display("PASSED");$finish(0);end
endmodule
