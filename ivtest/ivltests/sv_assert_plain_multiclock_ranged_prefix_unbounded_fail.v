module test;bit c1,c2,a,x,b;assert property(@(posedge c1)a##[1:$]x##1@(posedge c2)b);endmodule
