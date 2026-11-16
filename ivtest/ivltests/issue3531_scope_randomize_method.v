class C;
  int a;
  int hooks;
  constraint bad { a == 0; }
  function void pre_randomize(); hooks++; endfunction
  function void post_randomize(); hooks++; endfunction
  function void f();
    int ok;
    void'(std::randomize(a) with { a > 5; a < 10; });
    if (!(a > 5 && a < 10)) $fatal(1, "void constraint failed");
    ok = std::randomize(a) with { a == 12; };
    if (!ok || a != 12 || hooks != 0) $fatal(1, "expression failed");
  endfunction
endclass
module tb;
  initial begin
    C c; C other;
    c = new; other = new; other.a = 33;
    c.f();
    if (other.a != 33) $fatal(1, "wrong object");
    $display("PASS");
  end
endmodule
