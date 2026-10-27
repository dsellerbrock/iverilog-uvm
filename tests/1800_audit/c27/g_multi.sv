module M1; reg r = 1; endmodule
module top; parameter SIZE=2; genvar i,j,k,m;
 for (i=0;i<SIZE;i=i+1) begin:B1 M1 N1();
  for (j=0;j<SIZE;j=j+1) begin:B2 M1 N2(); end
  if (i>0) begin:B4 for (m=0;m<SIZE;m=m+1) begin:B5 M1 N4(); end end
 end
 initial #1 $display("G3 ok");
 initial #1 $display("G3H %b %b %b", B1[1].N1.r, B1[0].B2[1].N2.r, B1[1].B4.B5[0].N4.r);
endmodule
