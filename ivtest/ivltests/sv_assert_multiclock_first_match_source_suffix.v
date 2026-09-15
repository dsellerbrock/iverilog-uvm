module sv_assert_multiclock_first_match_source_suffix;
 bit c1=0,c2=0,a=0,b=1,x=0,good=0; int passes=0,fails=0,last=-1;
 always #10 c1=~c1; initial begin #5; forever #10 c2=~c2; end
 sp: assert property(@(posedge c1)
       first_match(a##[1:2]b)##1 x##1@(posedge c2)good)
     begin passes++;last=$time;end else begin fails++;last=$time;end
 initial begin
   #9 a=1;#2 a=0;$assertoff(0,sp);
   #38 x=1;                    // sampled at c1=50 and c1=70
   #11 good=1;                 // false at c2=55, true at c2=75
   #11 x=0; #19;
   if(passes!=0||fails!=1||last!=55)
     $fatal(1,"passes=%0d fails=%0d last=%0d",passes,fails,last);
   $display("PASSED");$finish(0);
 end
endmodule
