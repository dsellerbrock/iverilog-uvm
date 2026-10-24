module d1(input a, output y);
  assign y = a;
  specify
    specparam tr = 3, tf = 5;
    (a => y) = (tr, tf);
  endspecify
endmodule

module d2(input a, input en, output y);
  buf (y, a);
  specify
    if (en)  (a => y) = 2;
    if (!en) (a => y) = 7;
  endspecify
endmodule

module p30_specify;
  reg a = 0, b = 0, en = 1, p = 0;
  wire y1, y2, y3;
  d1 u1(a, y1);
  d2 u2(b, en, y2);
  d1 u3(p, y3);

  initial begin
    #10 a = 1; #2 $display("R1 %b", y1); #2 $display("R2 %b", y1);
    #6 a = 0; #4 $display("F1 %b", y1); #2 $display("F2 %b", y1);
    #4 b = 1; #1 $display("C1 %b", y2); #2 $display("C2 %b", y2);
    en = 0; #2 b = 0; #6 $display("C3 %b", y2); #2 $display("C4 %b", y2);
    #5 p = 1; #2 p = 0; #10 $display("P1 %b", y3);
  end
endmodule
