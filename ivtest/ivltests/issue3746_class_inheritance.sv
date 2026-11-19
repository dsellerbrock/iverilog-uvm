package bases;
  class Base #(int Tag = 2);
    int first, second;
    function new(int x, int y);
      first = x;
      second = y;
    endfunction
  endclass

  interface class Marker;
  endclass

  class OpenBase #(type T);
    int result;
    function new(int x, int y);
      result = x * 100 + y;
    endfunction
  endclass

`ifdef CHECK_DEFAULT_FORWARDING
  class Defaults #(int Kind = 13);
    int left, right;
    function new(int l = 17, int r = 37);
      left = l;
      right = r;
    endfunction
  endclass
`endif
endpackage

package subclasses;
  class Derived #(int N = 1) extends bases::Base#(.Tag(N))(.y(31), .x(7));
    int third, fourth;
    function new(int a, int b);
      third = a;
      fourth = b;
    endfunction
  endclass
endpackage

module top;
  class Base implements bases::Marker;
  endclass

  class SameScope extends Base;
  endclass

  class OpenDerived #(type T) extends bases::OpenBase#(T)(17, 29);
  endclass

  class Grandchild extends subclasses::Derived#(5);
    function new(int seed);
      super.new(seed + 3, seed + 9);
      $check_super_call(this, seed);
    endfunction
  endclass

`ifdef CHECK_DEFAULT_FORWARDING
  class Forwarded extends bases::Defaults#()(default);
    function new(default);
      $check_default_chain(this, l, r);
    endfunction
  endclass
  Forwarded f;
`endif

  bases::Base#(5) base5;
  bases::Base#(9) base9;
  subclasses::Derived#(5) derived5, derived5_again;
  subclasses::Derived#(9) derived9;
  Grandchild grandchild;
  Base unrelated;
  SameScope same_scope;
  bases::Marker marker;
  bases::OpenBase#(int) open_base;
  OpenDerived#(int) open_derived;

  initial begin
    derived5 = new(41, 43);
    grandchild = new(11);
    open_derived = new;
    if (derived5.first != 7 || derived5.second != 31 ||
        grandchild.first != 7 || grandchild.second != 31 ||
        grandchild.third != 14 || grandchild.fourth != 20 ||
        open_derived.result != 1729)
      $fatal(1, "constructor execution");
`ifdef CHECK_DEFAULT_FORWARDING
    f = new(29, 47);
    if (f.left != 29 || f.right != 47) $fatal(1, "forwarded arguments");
`endif
    $check_class_inheritance(base5, base9, derived5, derived5_again, derived9,
                             grandchild, unrelated, same_scope, marker,
                             open_base, open_derived);
  end
endmodule
