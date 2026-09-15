module test;bit c1,c2,a,b,c;int x;assert property(@(posedge c1)first_match((a,x=1)##[1:2]b)##1@(posedge c2)c);endmodule
