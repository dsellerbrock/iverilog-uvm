module sv_assert_multiclock_first_match_two_window_coincident;
 bit c1=0,c2=0,a=0,b=0,c=0,good=0;int ofail=0,nfail=0;
 always #10 c1=~c1; always #10 c2=~c2;
 ao:assert property(@(posedge c1)first_match(a##[1:2]b##[1:2]c)|->@(posedge c2)good)else begin ofail++;$display("OFAIL %0t",$time);end
 an:assert property(@(posedge c1)first_match(a##[1:2]b##[1:2]c)|=>@(posedge c2)good)else nfail++;
 initial begin #9 a=1;#2 a=0;$assertoff(0);#18 b=1;#20 c=1;#2 c=0;#9 good=1;#11;
 if(ofail!=1||nfail!=0)$fatal(1,"o=%0d n=%0d",ofail,nfail);$display("PASSED");$finish(0);end
endmodule
