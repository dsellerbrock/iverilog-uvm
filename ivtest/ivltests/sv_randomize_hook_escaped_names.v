// IEEE 1800-2017/2023 5.6.1 and 18.6.2: escaped identifiers retain
// exact callback identity through the runtime's encoded method labels.
class escaped_hook_base;
  rand bit value;
  int pre_calls, post_calls;
  virtual function int \method-name (); return 1; endfunction
endclass
class \hook-name  extends escaped_hook_base;
  function void pre_randomize(); pre_calls++; endfunction
  function void post_randomize(); post_calls++; endfunction
endclass
class \hook/<>-:;=?@[]^`{|}~  extends escaped_hook_base;
  function void pre_randomize(); pre_calls += 2; endfunction
  function void post_randomize(); post_calls += 2; endfunction
  virtual function int \method-name (); return 23; endfunction
endclass
module main;
  escaped_hook_base b;
  \hook-name h;
  \hook/<>-:;=?@[]^`{|}~ p;
  initial begin
    h = new; p = new;
    b = h;
    if (!b.randomize() || b.pre_calls != 1 || b.post_calls != 1)
      $fatal(1, "escaped class callback skipped");
    b = p;
    if (!b.randomize() with { value == 1; } || b.pre_calls != 2 || b.post_calls != 2)
      $fatal(1, "punctuation callback encoding");
    if (b.\method-name () != 23) $fatal(1, "escaped virtual method encoding");
    $display("PASSED");
  end
endmodule
