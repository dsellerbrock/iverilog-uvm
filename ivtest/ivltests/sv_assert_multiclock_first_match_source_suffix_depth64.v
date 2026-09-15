module sv_assert_multiclock_first_match_source_suffix_depth64;
 bit c1=0,c2=0,a=1,b=0,x=0; int passes=0,fails=0,last=-1;
 always #1 c1=~c1;
 sp: assert property(@(posedge c1)
       first_match(a##[1:31]b)##32 x##1@(posedge c2)1)
     begin passes++;last=$time;end else begin fails++;last=$time;end
 initial begin
   #2 $assertoff(0,sp); #60 b=1;#2 b=0; #62 x=1;#2 x=0; #2 c2=1;#2;
   if(passes!=1||fails!=0||last!=130)
     $fatal(1,"passes=%0d fails=%0d last=%0d",passes,fails,last);
   $display("PASSED");$finish(0);
 end
endmodule
