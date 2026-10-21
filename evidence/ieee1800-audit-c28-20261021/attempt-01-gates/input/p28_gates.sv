module p28_gates;
  wire o1, o2, o3, o4, o5, pu;
  wand wa;
  wor wo;
  tri tt;
  reg a = 0, ctl = 1'bx;

  and g1(o1, 1'b1, 1'bx);             // x
  and g2(o2, 1'b0, 1'bx);             // 0
  bufif1 g3(o3, 1'b1, ctl);           // H (1 or z)
  buf #(3, 5) g4(o4, a);              // rise 3, fall 5
  assign wa = 1'b1;
  assign wa = 1'b0;                   // wand -> 0
  assign wo = 1'b1;
  assign wo = 1'b0;                   // wor -> 1
  assign tt = 1'b1;
  assign tt = 1'b0;                   // equal-strength conflict -> x
  pullup(pu);

  initial begin
    #1 $display("G %b %b %v %b %b %b %v", o1, o2, o3, wa, wo, tt, pu);
    #9 a = 1;
    #2 $display("D1 %0t %b", $time, o4);
    #2 $display("D2 %0t %b", $time, o4);
    #7 a = 0;
    #4 $display("D3 %0t %b", $time, o4);
    #2 $display("D4 %0t %b", $time, o4);
  end
endmodule
