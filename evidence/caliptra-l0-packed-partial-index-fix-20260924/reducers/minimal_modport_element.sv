interface mif; logic [1:0][7:4] a; modport src(output a); endinterface
module wr(mif.src e); initial e.a[1] = 4'h9; endmodule
module t; mif p(); wr w(.e(p)); mif h(); initial h.a[1] = 4'h9;
  initial #1 $display("port=%b hier=%b", p.a, h.a); endmodule
