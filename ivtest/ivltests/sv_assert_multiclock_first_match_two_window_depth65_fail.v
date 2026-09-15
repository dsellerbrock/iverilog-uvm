module test; bit c1,c2,a,b,c;
 assert property(@(posedge c1)
   first_match(a##[1:32]b##[1:32]c)|->@(posedge c2)1);
endmodule
