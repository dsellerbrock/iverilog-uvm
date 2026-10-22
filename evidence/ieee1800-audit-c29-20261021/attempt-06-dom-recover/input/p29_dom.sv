`timescale 1ns/1ps

primitive domff(q, clk, d, clr);
  output q;
  reg q;
  input clk, d, clr;
  initial q = 0;
  table
  // clk d clr : q : q+
     ?   ?  1  : ? : 0;
     r   1  ?  : ? : 1;
     0   ?  f  : ? : -;
  endtable
endprimitive

module p29_dom;
  reg ck1 = 0, cl1 = 0, ck2 = 0, cl2 = 0, d = 1;
  wire qe, qd;
  domff ue(qe, ck1, d, cl1);
  domff ud(qd, ck2, d, cl2);
  initial begin
    #1 cl1 = 1; cl2 = 1;
    #1 $display("REC %b %b", qe, qd);
    #1 cl1 = 0;
    #2 ck1 = 1; ck2 = 1;
    #1 $display("EDGE %b", qe);
    $display("DOM %b", qd);
  end
endmodule
