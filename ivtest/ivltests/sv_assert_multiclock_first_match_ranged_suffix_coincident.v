module sv_assert_multiclock_first_match_ranged_suffix_coincident;
 bit c1=0,c2=0,a=0,b=1,x=0,good=0;int of=0,ot=-1,np=0,nf=0,nt=-1,pp=0,pf=0,pt=-1;
 always #10 c2=~c2; always #10 c1=~c1; // reverse declaration order, coincident edges
 oi:assert property(@(posedge c1)first_match(a##[1:2]b)##[1:2]x|->@(posedge c2)good)
   else begin of++;ot=$time;end
 ni:assert property(@(posedge c1)first_match(a##[1:2]b)##[1:2]x|=>@(posedge c2)good)
   begin np++;nt=$time;end else nf++;
 ps:assert property(@(posedge c1)first_match(a##[1:2]b)##[1:2]x##0@(posedge c2)good)
   begin pp++;pt=$time;end else pf++;
 initial begin #9 a=1;#2 a=0;$assertoff(0,oi);$assertoff(0,ni);$assertoff(0,ps);
   #38 x=1;#11 good=1;#11 x=0;#29;
   if(of!=1||ot!=50||np!=1||nf||nt!=90||pp!=1||pf||pt!=70)
     $fatal(1,"of%0d ot%0d np%0d nf%0d nt%0d pp%0d pf%0d pt%0d",of,ot,np,nf,nt,pp,pf,pt);
   $display("PASSED");$finish(0);end
endmodule
