module p06_19c_enum_numeric;
  int pass = 0, fail = 0;
  task automatic ck(input string id, input bit c);
    if (c) pass++;
    else begin fail++; $display("FAIL %s", id); end
  endtask

  typedef enum {red, green, blue, yellow, white, black} Colors;
  typedef enum {Mo, Tu, We, Th, Fr, Sa, Su} Week;
  Colors c;
  Week W;
  integer a, b;
  int I;
  bit ok;

  initial begin
    c = green;
    ck("eq_int", 1 == c && c == 1);
    a = blue * 3;
    ck("mul", a == 6);
    c = yellow;
    b = c + green;
    ck("add", b == 4);
    c = Colors'(c + 1);
    ck("cast_inc", c == white);
    W = Su;
    c = Colors'(W);
    ck("cast_oor", int'(c) == 6);
    I = c + W;
    ck("two_enum_add", I == 12);
    ok = $cast(c, 2);
    ck("cast_ok", ok && c == blue);
    c = black;
    ok = $cast(c, 99);
    ck("cast_fail_unchanged", !ok && c == black);
    $display("RESULT pass=%0d fail=%0d", pass, fail);
  end
endmodule
