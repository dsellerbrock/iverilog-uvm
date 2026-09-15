module sv_assert_multiclock_first_match_source_suffix_coincident;
 bit c1=0,c2=0,a=0,b=1,x=0,good=0; int op=0,of=0,np=0,nf=0,ot=-1,nt=-1;
 always #10 c1=~c1; always #10 c2=~c2;
 so: assert property(@(posedge c1) first_match(a##[1:2]b)##1 x##0@(posedge c2)good)
   begin op++;ot=$time;end else begin of++;ot=$time;end
 sn: assert property(@(posedge c1) first_match(a##[1:2]b)##1 x##1@(posedge c2)good)
   begin np++;nt=$time;end else begin nf++;nt=$time;end
 initial begin
   #9 a=1;#2 a=0;$assertoff(0,so);$assertoff(0,sn);
   #38 x=1;#2 x=0;#9 good=1;#20;
   if(op||of!=1||ot!=50||np!=1||nf||nt!=70)
     $fatal(1,"op=%0d of=%0d ot=%0d np=%0d nf=%0d nt=%0d",op,of,ot,np,nf,nt);
   $display("PASSED");$finish(0);
 end
endmodule
