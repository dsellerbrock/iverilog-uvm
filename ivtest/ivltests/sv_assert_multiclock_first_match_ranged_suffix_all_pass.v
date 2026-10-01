module sv_assert_multiclock_first_match_ranged_suffix_all_pass;
 bit c1=0,c2=0,a=0,b=1,x=0,good=1;int pp=0,pf=0,pt=-1,ip=0,ifail=0,it=-1;
 always #10 c1=~c1;initial begin #5;forever #10 c2=~c2;end
 ps:assert property(@(posedge c1)first_match(a##[1:2]b)##[1:2]x##1@(posedge c2)good)
   begin pp++;pt=$time;end else begin pf++;pt=$time;end
 is:assert property(@(posedge c1)first_match(a##[1:2]b)##[1:2]x|->@(posedge c2)good)
   begin ip++;it=$time;end else begin ifail++;it=$time;end
 initial begin #9 a=1;#2 a=0;$assertoff(0,ps);$assertoff(0,is);#38 x=1;#22 x=0;#29;
   if(pp!=1||pf||pt!=55||ip!=1||ifail||it!=75)$fatal(1,"pp%0d pf%0d pt%0d ip%0d if%0d it%0d",pp,pf,pt,ip,ifail,it);
   $display("PASSED");$finish(0);end
endmodule
