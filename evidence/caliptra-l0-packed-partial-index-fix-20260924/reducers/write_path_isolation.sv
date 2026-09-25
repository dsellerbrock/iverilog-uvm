interface mif; logic [3:0][17:4] a; logic [3:0][13:0] z; logic [17:4] s; modport src(output a, output z, output s); endinterface
module wr_port(mif.src e);                    // procedural element write through modport port
  for (genvar i = 0; i < 4; i++) begin : g
    always_comb begin e.a[i] = 14'h2000 + 14'(i); e.z[i] = 14'h2000 + 14'(i); end
  end
  always_comb e.s[17:4] = 14'h2003;
endmodule
module wr_const(mif.src e);                   // constant (non-genvar) element index
  initial begin #0; e.a[3] = 14'h2003; e.a[0] = 14'h2000; end
endmodule
module t;
  mif p();  wr_port w(.e(p));
  mif c();  wr_const wc(.e(c));
  mif h();  initial begin #0; h.a[3] = 14'h2003; h.a[0] = 14'h2000; end   // hierarchical, same scope
  mif f();  initial f.a = {14'h2003, 14'h2002, 14'h2001, 14'h2000};
  initial begin
    #1;
    $display("A port genvar  a=%h (want 800e0028006000) z(LSB0)=%h s=%h", p.a, p.z, p.s);
    $display("B port const   a=%h (want 800cxxxxxxx000-ish: a[3]=2003 a[0]=2000) a[3]=%h a[0]=%h", c.a, c.a[3], c.a[0]);
    $display("C hier const   a=%h a[3]=%h a[0]=%h", h.a, h.a[3], h.a[0]);
    $display("D whole+read   a=%h a[3]=%h a[0]=%h", f.a, f.a[3], f.a[0]);
  end
endmodule
