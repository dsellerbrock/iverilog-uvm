module top; parameter genblk2 = 0; genvar i;
 if (genblk2) logic a; else logic b;
 if (genblk2) logic a; else logic b;
 for (i=0;i<1;i=i+1) begin : g1 if (1) logic a; end
 for (i=0;i<1;i=i+1) if (1) logic a;
 if (1) logic a;
 initial begin top.genblk1.b = 1; top.genblk02.b = 1; top.g1[0].genblk1.a = 1; top.genblk4[0].genblk1.a = 1; top.genblk5.a = 1;
  #1 $display("G5 %b %b %b", top.genblk1.b, top.genblk02.b, top.genblk5.a); end
endmodule
