module top #(parameter p=1, q=2); wire a=1; wire b=0; wire c;
 if (p==1) if (q==0) begin:u1 wire w=0; and g1(c,a,b); end else if (q==2) begin:u1 wire w=1; or g1(c,a,b); end else ;
 else if (p==2) case (q) 0,1,2: begin:u1 wire w=0; xor g1(c,a,b); end default: begin:u1 wire w=0; xnor g1(c,a,b); end endcase
 initial #1 $display("G4 %b %b", c, u1.w);
endmodule
