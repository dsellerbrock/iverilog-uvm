module test;
reg c1=0,c2=0,a=1,b=1,good=1;int failures=0;
always #1 c1=~c1;
assert property (@(posedge c1) a ##[1:2] b |-> @(posedge c2) good) else failures++;
initial begin
 #2;a=0;#2000;
 // White-box lifecycle check: only two real child obligations remain.
 if(_ivl_sva0_mcrkind0.num()>32)$fatal(1,"retired lifecycle records retained: %0d",_ivl_sva0_mcrkind0.num());
 if(failures)$fatal(1,"unexpected failure");$display("PASSED");$finish(0);
end
endmodule
