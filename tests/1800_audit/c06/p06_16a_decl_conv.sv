module p06_16a;
  int pass=0, fail=0;
  task automatic ck(input string id, input bit c); if (c) pass++; else begin fail++; $display("FAIL %s", id); end endtask
  typedef logic [15:0] r_t;
  parameter string dn = "John Smith";
  string myName = dn, e, s0 = "String literal assign", s1 = "hello\0world", b = "", s;
  bit [11:0] b12 = 12'ha41;
  string s2 = string'(b12);
  string a = {"Hi", b};
  byte c = "A";  bit [10:0] b11 = "\x41";  bit [1:4][7:0] h = "hello";
  r_t r;  integer i = 1;
  initial begin
    ck("decl_empty", e == "" && e.len() == 0);
    ck("param_init", myName == "John Smith");
    ck("nul_strip", s1 == "helloworld" && s1.len() == 10);
    ck("cast12", s2.len() == 2 && s2[0] == 8'h0a && s2[1] == 8'h41);
    ck("init_concat", a == "Hi");
    ck("lit_byte", c == 8'h41);  ck("lit_11", b11 == 11'h041);  ck("lit_trunc", h == 32'h656c6c6f);
    s = "\0"; ck("only_nul", s.len() == 0);
    s = string'(16'h0041); ck("cast_zero_byte", s == "A" && s.len() == 1);
    s = string'(8'h00); ck("cast_zero", s.len() == 0);
    s = string'(9'h141); ck("cast9", s.len() == 2 && s[0] == 8'h01 && s[1] == 8'h41);
    s = string'(32'h41424344); ck("cast32", s == "ABCD");
    s = string'(8'h5a); ck("cast_shrink", s == "Z" && s.len() == 1);
    r = r_t'(a); ck("str2r", r == 16'h4869);
    b = string'(r); ck("r2str", b == "Hi" && b.len() == 2);
    b = {5{"Hi"}}; ck("repl_const", b == "HiHiHiHiHi");
    i = 1; a = {i{"Hi"}}; ck("repl_nc1", a == "Hi");
    i = 3; a = {i{"Hi"}}; ck("repl_nc3", a == "HiHiHi");
    i = 0; a = {i{"Hi"}}; ck("repl_zero", a == "" && a.len() == 0);
    b = "ab"; i = 2; a = {i{b}}; ck("repl_var", a == "abab");
    a = {a, b}; ck("cat_self", a == "ababab");
    a = {"Hi", b}; ck("cat_lit_var", a == "Hiab");
    r = {"H", ""}; ck("cat_int", r == 16'h4800);
    b = {"H", ""}; ck("cat_str", b == "H" && b.len() == 1);
    s = {"a", "b"}; ck("lits2str", s == "ab");
    ck("bits", $bits({"a", "b"}) == 16);
    $display("RESULT pass=%0d fail=%0d", pass, fail);
  end
endmodule
