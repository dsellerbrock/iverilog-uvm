module sv_assert_multiclock_first_match_ranged_suffix_cover;
 bit c1=0,c2=0,a=0,b=1,x=0,good=1;int pc=0,ic=0,pt=-1,it=-1;
 always #10 c1=~c1;initial begin #5;forever #10 c2=~c2;end
 ps:cover property(@(posedge c1)first_match(a##[1:2]b)##[1:2]x##1@(posedge c2)good)begin pc++;pt=$time;end
 is:cover property(@(posedge c1)first_match(a##[1:2]b)##[1:2]x|->@(posedge c2)good)begin ic++;it=$time;end
 initial begin #9 a=1;#2 a=0;$assertoff(0,ps);$assertoff(0,is);#38 x=1;#22 x=0;#29;
   if(pc!=1||pt!=55||ic!=1||it!=75)$fatal(1,"pc%0d pt%0d ic%0d it%0d",pc,pt,ic,it);
   $display("PASSED");$finish(0);end
endmodule
