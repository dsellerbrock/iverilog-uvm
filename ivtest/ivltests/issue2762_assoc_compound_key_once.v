// Issue #2762: a compound assignment or ++/-- on an associative-array
// element evaluates its key expression once (IEEE 1800-2023 11.4.1 "any
// left-hand index expression is only evaluated once"; 11.4.2 increment and
// decrement behave as blocking assignments). Also covers ++/-- used as an
// expression on a local associative element, which yields the old (postfix)
// or new (prefix) value and creates a missing element from its default.
module issue2762_assoc_compound_key_once;
  class K; endclass
  class C;
    int pm[string];
    function void bump(); pm[skey()] += 2; pm[skey()]++; endfunction
  endclass
  int sm[string];
  int im[int];
  int wm[*];
  int om[K];
  byte bm[int];
  real rm[int];
  int keys, v, failed = 0;
  byte bv;
  string trace;
  K kk;
  C c;
  function automatic string skey(); keys++; return "k"; endfunction
  function automatic int ikey(); keys++; return 1; endfunction
  function automatic K okey(); keys++; return kk; endfunction
  function automatic int f(); trace = {trace, "f"}; return 1; endfunction
  function automatic int g(); trace = {trace, "g"}; return 1; endfunction
  task check(string what, int got, int want, int got_keys, int want_keys);
    if (got !== want || got_keys !== want_keys) begin
      $display("FAILED: %s = %0d (want %0d), keys = %0d (want %0d)",
               what, got, want, got_keys, want_keys);
      failed++;
    end
  endtask
  initial begin
    kk = new; c = new;
    keys = 0; sm[skey()] += 1;  check("sm +=", sm["k"], 1, keys, 1);
    keys = 0; sm[skey()]++;     check("sm ++", sm["k"], 2, keys, 1);
    keys = 0; im[ikey()] += 1;  check("im +=", im[1], 1, keys, 1);
    keys = 0; ++im[ikey()];     check("++im", im[1], 2, keys, 1);
    keys = 0; wm[ikey()] -= 3;  check("wm -=", wm[1], -3, keys, 1);
    keys = 0; om[okey()] += 4;  check("om +=", om[kk], 4, keys, 1);
    keys = 0; bm[ikey()] -= 300; check("bm -=", bm[1], -44, keys, 1);
    keys = 0; rm[ikey()] += 1.5;
    if (rm[1] != 1.5 || keys != 1) begin
      $display("FAILED: rm += gave %g keys=%0d", rm[1], keys); failed++;
    end
    keys = 0; c.bump();         check("pm in method", c.pm["k"], 3, keys, 2);
    keys = 0; c.pm[skey()] *= 4; check("c.pm *=", c.pm["k"], 12, keys, 1);
    trace = ""; im[f()] += g();
    if (trace != "fg") begin
      $display("FAILED: evaluation order %s (want fg)", trace); failed++;
    end
    // ++/-- as an expression.
    im.delete();
    keys = 0; v = im[ikey()]++; check("v = im[k]++", v, 0, keys, 1);
    check("im after postfix", im[1], 1, 0, 0);
    keys = 0; v = ++im[ikey()]; check("v = ++im[k]", v, 2, keys, 1);
    keys = 0; v = sm[skey()]--; check("v = sm[k]--", v, 2, keys, 1);
    check("sm after postfix --", sm["k"], 1, 0, 0);
    bm[2] = 127; bv = bm[2]++;
    if (bv != 127 || bm[2] != -128) begin
      $display("FAILED: byte wrap bv=%0d bm=%0d", bv, bm[2]); failed++;
    end
    im[5] = 10; v = im[5]++ + im[5]++; check("two postfix", v, 21, 0, 0);
    check("im[5] after two", im[5], 12, 0, 0);
    if (failed == 0) $display("PASSED");
  end
endmodule
