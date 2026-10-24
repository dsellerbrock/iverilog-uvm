module t;
  class C; string name = "obj"; static string sn = "stat"; endclass
  typedef struct { string s; } st_t;
  st_t st; C o; string loc = "obj", n;
  initial begin o = new; st.s = "xyz";
    o.name.putc(0, "O"); $display("B putc member='%s'", o.name);
    o.name = "obj"; o.name[0] = "O"; $display("B idxwr member='%s'", o.name);
    st.s[0] = "X"; $display("B struct idxwr='%s'", st.s);
    C::sn[0] = "S"; $display("B static idxwr='%s'", C::sn);
  end
endmodule
