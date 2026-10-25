// IEEE 1800-2017/2023 25.5.4: named modport ports expose their expressions.
interface I;
  logic [7:0] r; const int x=1; bit R;
  modport A (output .P(r[3:0]), input .Q(x), R);
  modport B (output .P(r[7:4]), input .Q(2), R);
endinterface
module M ( interface i); initial i.P = i.Q; endmodule
module sv_modport_expression;
  I i1 (); M u1 (i1.A); M u2 (i1.B);
  initial #1 $display("%b", i1.r);
endmodule
