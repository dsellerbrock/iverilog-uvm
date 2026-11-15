// IEEE 1800-2023 11.4.11: under an ambiguous condition, arrays are
// "combined element by element. If the elements match, the element shall
// be returned. If they do not match, then the value specified in Table 7-1
// for that element's type shall be returned."
module issue3188_cond_x_array;
  int a[3] = '{1, 2, 3}, b[3] = '{1, 3, 3}, d[3];
  integer xa[2] = '{1, 5}, xb[2] = '{1, 7}, xd[2];
  byte ba[2] = '{8'd4, 8'd9}, bb[2] = '{8'd4, 8'd8}, bd[2];
  int m1[2][2] = '{'{1, 2}, '{3, 4}}, m2[2][2] = '{'{1, 2}, '{3, 5}}, md[2][2];
  int da[] = '{1, 2}, db[] = '{1, 3}, dd[];
  real ra[] = '{1.5, 2.5}, rb[] = '{1.5, 3.5}, rd[];
  logic c;
  initial begin
    c = 1'bx;
    d = c ? a : b;    $display("int %0d %0d %0d", d[0], d[1], d[2]);
    xd = c ? xa : xb; $display("integer %0d %b", xd[0], xd[1][3:0]);
    bd = c ? ba : bb; $display("byte %0d %0d", bd[0], bd[1]);
    md = c ? m1 : m2; $display("2-D %0d %0d %0d %0d", md[0][0], md[0][1], md[1][0], md[1][1]);
    dd = c ? da : db; $display("dyn %p", dd);
    rd = c ? ra : rb; $display("real %p", rd);
    c = 1'bz;
    d = c ? a : b;    $display("z %0d %0d %0d", d[0], d[1], d[2]);
    c = 1'b1;
    d = c ? a : b;    $display("true %0d %0d %0d", d[0], d[1], d[2]);
    dd = c ? da : db; $display("dyn true %p", dd);
    c = 1'b0;
    d = c ? a : b;    $display("false %0d %0d %0d", d[0], d[1], d[2]);
    dd = c ? da : db; $display("dyn false %p", dd);
  end
endmodule
