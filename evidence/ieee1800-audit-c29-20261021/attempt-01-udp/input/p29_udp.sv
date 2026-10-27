primitive mux(o, s, a, b);
  output o;
  input s, a, b;
  table
    0 1 ? : 1;
    0 0 ? : 0;
    1 ? 1 : 1;
    1 ? 0 : 0;
    x 0 0 : 0;
    x 1 1 : 1;
  endtable
endprimitive

primitive latch(q, c, d);
  output q;
  reg q;
  input c, d;
  initial q = 1'b1;
  table
    1 0 : ? : 0;
    1 1 : ? : 1;
    0 ? : ? : -;
  endtable
endprimitive

primitive dff(q, c, d);
  output q;
  reg q;
  input c, d;
  table
    (01) 0 : ? : 0;
    (01) 1 : ? : 1;
    (0?) 1 : 1 : 1;
    (0?) 0 : 0 : 0;
    (?0) ? : ? : -;
    ? (??) : ? : -;
  endtable
endprimitive

module p29_udp;
  reg s, a, b, c = 0, d = 0, k = 0, e = 1;
  wire o, q, f;
  mux m(o, s, a, b);
  latch l(q, c, d);
  dff ff(f, k, e);

  initial begin
    #1 $display("L0 %b", q);
    s=0; a=1; b=0; #1 $display("M1 %b", o);
    s=1;           #1 $display("M2 %b", o);
    s=1'bx; a=1; b=1; #1 $display("M3 %b", o);
    b=0;           #1 $display("M4 %b", o);
    s=1'bz; a=0; b=0; #1 $display("M5 %b", o);
    c=1; d=0; #1 $display("L1 %b", q); c=0; d=1; #1 $display("L2 %b", q);
    k=1; #1 $display("F1 %b", f); e=0; #1 $display("F2 %b", f);
    k=0; #1 k=1; #1 $display("F3 %b", f);
    k=1'bx; #1 $display("F4 %b", f);
  end
endmodule
