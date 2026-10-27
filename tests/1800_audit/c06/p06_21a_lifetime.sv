int cu_var = 4;
program automatic prog;
  int i = 0;
  task t(int a);
    int loc = 0;
    loc++;
    i++;
    $display("PROG loc=%0d i=%0d", loc, i);
  endtask
  initial begin t(1); t(2); end
endprogram

module automatic m2;
  function int f(); int c = 0; c++; return c; endfunction
  initial begin int a, b; a = f(); b = f(); $display("M2 f1=%0d f2=%0d", a, b); end
endmodule

class C;
  function int f(); int c = 0; c++; return c; endfunction
endclass

module p06_21a;
  int pass = 0, fail = 0;
  task automatic ck(input string id, input bit c);
    if (c) pass++; else begin fail++; $display("FAIL %s", id); end
  endtask
  int a2_last, s3_last, a3_last, sc_last;
  string s_auto = "", s_static = "";
  C co;
  task automatic t1();
    int auto2 = 0;
    static int st3 = 0;
    automatic int auto3 = 0;
    auto2++; st3++; auto3++;
    a2_last = auto2; s3_last = st3; a3_last = auto3;
  endtask
  task st_default(); static int cnt = 0; cnt++; sc_last = cnt; endtask
  prog pg();
  m2 mm();
  initial begin
    ck("compunit_var", cu_var == 4);
    t1(); t1(); t1();
    ck("auto_task_locals", a2_last == 1 && a3_last == 1 && s3_last == 3);
    ck("hier_static_in_auto_task", p06_21a.t1.st3 == 3);
    st_default(); st_default(); ck("static_task_var", sc_last == 2);
    for (int i = 0; i < 3; i++) begin
      automatic int loop3 = 0;
      for (int j = 0; j < 3; j++) begin loop3++; s_auto = {s_auto, $sformatf("%0d", loop3)}; end
    end
    for (int i = 0; i < 3; i++) begin
      static int loop2 = 0;
      for (int j = 0; j < 3; j++) begin loop2++; s_static = {s_static, $sformatf("%0d", loop2)}; end
    end
    ck("loop_auto", s_auto == "123123123");
    ck("loop_static", s_static == "123456789");
    co = new; ck("class_method_auto", co.f() == 1 && co.f() == 1);
    $display("RESULT pass=%0d fail=%0d", pass, fail);
  end
endmodule
