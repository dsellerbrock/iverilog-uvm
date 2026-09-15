module test; bit c1,c2,a,b,c,d;
 assert property(@(posedge c1)a|->@(posedge c2)(b##1 c)[*1:$]##1 d);
endmodule
