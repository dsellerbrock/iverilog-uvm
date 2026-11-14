// IEEE 1800-2023 11.4.11: under an ambiguous (x or z) condition, operands
// that are not logically equivalent give "the value specified in Table 7-1
// for the resulting type". For an unpacked struct that is each member's
// own Table 7-1 value. Equivalent operands give their value.
module sv_struct_cond_x_default;
  typedef struct { int i; logic [3:0] l; } in_t;
  typedef struct { int i; logic [3:0] l; string s; real r; in_t n; } s_t;
  s_t sa = '{2, 4'b1010, "a", 1.5, '{3, 4'b0011}};
  s_t sb = '{9, 4'b1001, "b", 2.5, '{4, 4'b0100}};
  s_t sd, ta[2], tb[2], td[2];
  logic c;

  task show(string tag, s_t v);
    $display("%s %0d %b '%s' %0.1f %0d %b", tag, v.i, v.l, v.s, v.r, v.n.i, v.n.l);
  endtask

  initial begin
    ta[0] = sa; ta[1] = sa; tb[0] = sb; tb[1] = sa;
    c = 1'bx;
    sd = c ? sa : sb;  show("x differ", sd);
    sd = c ? sa : sa;  show("x same", sd);
    td = c ? ta : tb;  show("arr[0]", td[0]); show("arr[1]", td[1]);
    c = 1'bz;
    sd = c ? sb : sa;  show("z differ", sd);
    c = 1'b1;
    sd = c ? sa : sb;  show("true", sd);
    c = 1'b0;
    sd = c ? sa : sb;  show("false", sd);
  end
endmodule
