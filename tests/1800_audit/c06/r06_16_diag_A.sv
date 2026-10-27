module t;
  class C; string name = "obj"; static string sn = "stat"; endclass
  typedef struct { string s; } st_t;
  st_t st; C o; string loc = "obj", n;
  initial begin o = new; st.s = "xyz";
    $display("A len member=%0d static=%0d struct=%0d local=%0d", o.name.len(), C::sn.len(), st.s.len(), loc.len());
    $display("A getc=%0d idx=%0d substr=%s cmp=%0d upper=%s", o.name.getc(1), o.name[1], o.name.substr(1,2), o.name.compare("obj"), o.name.toupper());
    n = o.name; $display("A copy len=%0d eq=%b", n.len(), o.name == loc);
  end
endmodule
