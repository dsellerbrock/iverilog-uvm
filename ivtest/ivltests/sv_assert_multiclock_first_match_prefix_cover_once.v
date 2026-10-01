module test; bit c1=0,c2=0,a=0,b=1,c=1; int hits=0,ht=-1; always #10 c1=~c1; initial begin #5;forever #10 c2=~c2;end
sp:cover property(@(posedge c1) first_match(a##[1:2]b)##1@(posedge c2)c)begin hits++;ht=$time;end
initial begin #9 a=1;#2 a=0;$assertoff(0,sp);#60;if(hits!=1||ht!=35)$fatal(1,"hits%0d ht%0d",hits,ht);$display("PASSED");$finish(0);end endmodule
