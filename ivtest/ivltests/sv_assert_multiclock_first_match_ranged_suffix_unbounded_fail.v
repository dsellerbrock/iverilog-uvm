module test;bit c1,c2,a,b,x;
 assert property(@(posedge c1)first_match(a##[1:2]b)##[1:$]x##1@(posedge c2)1);
endmodule
