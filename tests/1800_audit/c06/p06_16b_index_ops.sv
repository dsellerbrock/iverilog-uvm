module p06_16b;
  int pass=0, fail=0;
  task automatic ck(input string id, input bit c); if (c) pass++; else begin fail++; $display("FAIL %s", id); end endtask
  string s, t = "abc", u = "abd", v = "ab", e, z = "Z", la = "a", sb = "b", sa = "aaaa";
  int n;
  initial begin
    s = "abc";
    ck("idx", s[0] == "a" && s[1] == "b" && s[2] == "c");
    n = 3;  ck("idx_hi", s[n] == 0);
    n = -1; ck("idx_neg", s[n] == 0);
    ck("idx_empty", e[0] == 0);  ck("idx_byte", $bits(s[0]) == 8);
    s[0] = "h"; ck("idx_wr", s == "hbc");
    s[1] = "\0"; ck("wr_nul", s == "hbc" && s.len() == 3);
    n = 5;  s[n] = "x"; ck("wr_hi", s == "hbc" && s.len() == 3);
    n = -1; s[n] = "x"; ck("wr_neg", s == "hbc" && s.len() == 3);
    s.putc(-1, "z"); s.putc(3, "z"); ck("putc_oob", s == "hbc");
    s.putc(0, 0); ck("putc_zero", s == "hbc");
    s.putc(0, "X"); ck("putc", s == "Xbc" && s.len() == 3);
    ck("getc", s.getc(0) == "X" && s.getc(1) == "b");
    n = -1; ck("getc_neg", s.getc(n) == 0);
    n = 3;  ck("getc_hi", s.getc(n) == 0);
    ck("eq", s == "Xbc" && s != "Xbd" && t == "abc" && t != u);
    ck("lt", t < u && t <= u && u > t && u >= t);
    ck("not", !(t > u) && !(t >= u) && !(u < t) && !(u <= t));
    ck("prefix", v < t && t > v && v <= t && t >= v);
    ck("equal", t <= t && t >= t && !(t < t) && !(t > t));
    ck("empty", e < t && !(t < e));
    ck("lit", t < "abd" && "abb" < t);
    ck("case", z < la);  ck("lex", sb > sa);
    $display("RESULT pass=%0d fail=%0d", pass, fail);
  end
endmodule
