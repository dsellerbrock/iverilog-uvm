module test;bit c1,c2,a,b,c;property p;int x;@(posedge c1)first_match((a,x=1)##[1:2]b)##1@(posedge c2)c;endproperty assert property(p);endmodule
