// IEEE 1800-2017/2023 13.5.5: parentheses may be omitted from a class
// method call when every formal has a default. A later declaration is legal
// under 13.7. Both unqualified and class-property receiver paths matter.

class score;
  int current_state = 7;

  function int compare();
    int value = 7;
    if (value > get_current_max_version) return 1;
    else if (value == get_current_max_version) return 2;
    return 3;
  endfunction

  function int read_bare(); return get_current_max_version; endfunction
  function int read_explicit(); return get_current_max_version(); endfunction

  function int shadow();
    int get_current_max_version = 41;
    return get_current_max_version;
  endfunction

  virtual function int get_current_max_version(int state = current_state);
    return state;
  endfunction
  function int one_required(int x, int y = 2); return x + y; endfunction
  function int explicit_required(); return one_required(4); endfunction
endclass

class base;
  int value = 12;
  function int inherited_default(int v = value); return v; endfunction
  static function int two_defaults(int a = 2, int b = 3);
    return a + b;
  endfunction
endclass

class child extends base;
  function int read_inherited(); return inherited_default; endfunction
  function int read_static(); return two_defaults; endfunction
endclass

class holder;
  score sb;
  function new(); sb = new; endfunction
  function int read_property(); return sb.get_current_max_version; endfunction
endclass

module main;
  score s;
  child c;
  holder h;

  initial begin
    s = new;
    c = new;
    h = new;
    if (s.compare() !== 2) $fatal(1, "later defaulted comparison");
    if (s.read_bare() !== 7) $fatal(1, "later bare call");
    if (s.read_explicit() !== 7) $fatal(1, "explicit call");
    if (s.shadow() !== 41) $fatal(1, "local variable precedence");
    if (s.explicit_required() !== 6) $fatal(1, "required explicit call");
    s.current_state = 9;
    if (s.read_bare() !== 9) $fatal(1, "default evaluated at call time");
    if (c.read_inherited() !== 12) $fatal(1, "inherited method");
    if (c.read_static() !== 5) $fatal(1, "two static defaults");
    if (h.read_property() !== 7) $fatal(1, "property receiver");
    if (h.sb.get_current_max_version !== 7)
      $fatal(1, "nested property receiver");
    if (h.sb.get_current_max_version() !== 7)
      $fatal(1, "nested explicit receiver");
    h.sb.current_state = 11;
    if (h.read_property() !== 11)
      $fatal(1, "receiver default evaluated at call time");
    $display("PASSED");
  end
endmodule
