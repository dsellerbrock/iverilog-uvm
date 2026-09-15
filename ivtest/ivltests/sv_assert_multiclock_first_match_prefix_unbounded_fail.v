module test;bit c1,c2,a,b,c;assert property(@(posedge c1)first_match(a##[1:$]b)##1@(posedge c2)c);endmodule
