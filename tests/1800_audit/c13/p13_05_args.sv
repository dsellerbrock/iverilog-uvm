module top;
  int fails = 0;
  task automatic chk(string id, bit ok);
    if (ok) $display("PASS %s", id); else begin $display("FAIL %s", id); fails++; end
  endtask
  typedef struct { int a; } s_t;
  class C; int p; endclass
  int g, r, arr[4]; s_t st; C c;
  function automatic int byval(int x); x = x + 1; return x; endfunction
  task automatic setref(ref int x, input int v); x = v; endtask
  task automatic seen(ref int x); x = 7; r = g; x = 8; endtask
  function automatic int cref(const ref int x); return x + 1; endfunction
  task automatic href(ref C h); h = new; h.p = 5; endtask
  task automatic rd(int j = 0, int k, int data = 1); r = j*100 + k*10 + data; endtask
  function automatic int dflt(int x = g); return x; endfunction
  task automatic t1(output int o = g); o = 42; endtask
  initial begin
    g = 1; r = byval(g); chk("13.5.1.by_value_copy", g == 1 && r == 2);
    setref(g, 3); chk("13.5.2.ref_variable", g == 3);
    seen(g); chk("13.5.2.ref_change_visible_before_return", r == 7 && g == 8);
    setref(st.a, 4); chk("13.5.2.ref_struct_member", st.a == 4);
    setref(arr[2], 6); chk("13.5.2.ref_unpacked_elem", arr[2] == 6);
    c = new; setref(c.p, 9); chk("13.5.2.ref_class_property", c.p == 9);
    chk("13.5.2.const_ref_read", cref(g) == 9);
    c = null; href(c); chk("13.5.2.ref_object_handle", c != null && c.p == 5);
    rd(, 5);    chk("13.5.3.read(,5)", r == 51);
    rd(2, 5);   chk("13.5.3.read(2,5)", r == 251);
    rd(, 5, );  chk("13.5.3.read(,5,)", r == 51);
    rd(, 5, 7); chk("13.5.3.read(,5,7)", r == 57);
    rd(1, 5, 2); chk("13.5.3.read(1,5,2)", r == 152);
    g = 11; chk("13.5.3.default_evaluated_per_call_a", dflt() == 11);
    g = 12; chk("13.5.3.default_evaluated_per_call_b", dflt() == 12);
    t1(); chk("13.5.3.output_default_binds", g == 42);
    $display("DONE fails=%0d", fails);
  end
endmodule
