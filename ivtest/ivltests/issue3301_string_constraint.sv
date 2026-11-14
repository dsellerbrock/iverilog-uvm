module issue3301_string_constraint;
  class C;
    rand int n;
    string s = "abc";
    int index = 1;
    constraint c { n == s.len() + s[index]; }
  endclass

  C c = new;
  int ok;
  initial begin
    ok = c.randomize();
    if (!ok || c.n != 101) $fatal(1, "initial: ok=%0d n=%0d", ok, c.n);
    c.s = "hi";
    c.index = 1;
    ok = c.randomize();
    if (!ok || c.n != 107) $fatal(1, "changed: ok=%0d n=%0d", ok, c.n);
    c.index = 10;
    ok = c.randomize();
    if (!ok || c.n != 2) $fatal(1, "out of range: ok=%0d n=%0d", ok, c.n);
    c.s = "";
    ok = c.randomize();
    if (!ok || c.n != 0) $fatal(1, "empty: ok=%0d n=%0d", ok, c.n);
    c.s = "\xff";
    c.index = 0;
    ok = c.randomize();
    if (!ok || c.n != 0) $fatal(1, "signed byte: ok=%0d n=%0d", ok, c.n);
    $display("PASS");
  end
endmodule
