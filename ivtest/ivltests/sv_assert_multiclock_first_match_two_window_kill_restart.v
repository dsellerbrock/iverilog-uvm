module sv_assert_multiclock_first_match_two_window_kill_restart;
 bit c1=0,c2=0,a=0,b=1,c=1,good=1; int passes=0,fails=0,last=-1;
 always #10 c1=~c1;
 initial begin #5; forever #10 c2=~c2; end
 sp: assert property(@(posedge c1)
       first_match(a##[1:2]b##[1:2]c)|->@(posedge c2)good)
     begin passes++; last=$time; end
     else begin fails++; last=$time; end
 initial begin
   #9 a=1; #2 a=0; $assertoff(0,sp);
   #29 $assertkill(0,sp); #1 $asserton(0,sp);
   #8 a=1; #2 a=0; $assertoff(0,sp);
   #49;
   if (passes!=1 || fails!=0 || last!=95)
     $fatal(1,"passes=%0d fails=%0d last=%0d",passes,fails,last);
   $display("PASSED"); $finish(0);
 end
endmodule
