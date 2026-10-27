`timescale 1ns/1ns
module d1(input a, output y);
  assign y = a;
  specify
    specparam tr = 1, tf = 1;
    (a => y) = (tr, tf);
  endspecify
endmodule

module p32_label;
  reg a = 0;
  wire y;
  d1 u1(a, y);
  initial begin
`ifdef LABEL_OK
    $sdf_annotate("p32_label_ok.sdf", p32_label);
`elsif LABEL_MIXED
    $sdf_annotate("p32_label_mixed.sdf", p32_label);
`else
    $sdf_annotate("p32_label_ctl.sdf", p32_label);
`endif
    #10 a = 1; #3 $display("R1 %b", y); #2 $display("R2 %b", y);
    #5 a = 0; #5 $display("F1 %b", y); #2 $display("F2 %b", y);
    #1 $finish;
  end
endmodule
