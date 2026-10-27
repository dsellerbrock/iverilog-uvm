module p06_16c;
  int pass=0, fail=0;
  task automatic ck(input string id, input bit c); if (c) pass++; else begin fail++; $display("FAIL %s", id); end endtask
  class C; string name = "obj"; endclass
  function string f(); return "zz"; endfunction
  string m = "MiXed1", t = "abc", u = "abd", v = "ab", up = "ABC", w = "abcdef", e, s;
  string arr[3] = '{"a", "bb", "ccc"};
  string q[$];
  C o;
  initial begin
    ck("len", t.len() == 3 && e.len() == 0 && w.len() == 6);
    ck("upper", m.toupper() == "MIXED1" && m == "MiXed1");
    ck("lower", m.tolower() == "mixed1" && m == "MiXed1");
    ck("cmp_eq", t.compare("abc") == 0);
    ck("cmp_lt", t.compare("abd") < 0 && v.compare(t) < 0);
    ck("cmp_gt", u.compare(t) > 0 && t.compare(v) > 0);
    ck("cmp_empty", e.compare(t) < 0 && t.compare(e) > 0);
    ck("cmp_case", up.compare("abc") < 0);
    ck("icmp_eq", up.icompare("abc") == 0 && up.icompare(t) == 0);
    ck("icmp_lt", up.icompare("abd") < 0 && u.icompare(up) > 0);
    ck("icmp_prefix", v.icompare("ABC") < 0);
    ck("substr", w.substr(1, 3) == "bcd" && w.substr(0, 0) == "a" && w.substr(5, 5) == "f" && w.substr(0, 5) == "abcdef");
    ck("substr_bad", w.substr(-1, 2) == "" && w.substr(3, 2) == "" && w.substr(2, 6) == "" && w.substr(2, 9) == "");
    ck("chain", m.toupper().len() == 6 && m.substr(1, 2).toupper() == "IX");
    ck("fn_ret", f().len() == 2 && f().toupper() == "ZZ");
    s = ""; for (int k = 0; k < 1000; k++) s = {s, "x"};
    ck("grow", s.len() == 1000);
    s = "ab"; ck("shrink", s.len() == 2);
    o = new; ck("member", o.name.len() == 3 && o.name.toupper() == "OBJ");
    o.name[0] = "O"; ck("member_wr", o.name == "Obj");
    ck("arr", arr[2].len() == 3 && arr[1].toupper() == "BB");
    q.push_back("x"); q.push_back("yy"); ck("queue", q[1].len() == 2);
    $display("RESULT pass=%0d fail=%0d", pass, fail);
  end
endmodule
