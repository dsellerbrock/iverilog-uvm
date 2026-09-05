// IEEE 1800-2017/2023 18.6.2, 18.6.3, 18.11: virtual randomize()
// selects the dynamic object's callbacks, including checker calls. Direct
// calls to nonvirtual hooks retain ordinary static method dispatch.
class hook_base;
  rand int value;
  int pre_base, post_base;
  constraint bounded { value inside {[1:10]}; }
  function void pre_randomize(); pre_base++; endfunction
  function void post_randomize(); post_base++; endfunction
endclass
class hook_mid extends hook_base;
  int pre_mid;
  function void pre_randomize(); pre_mid++; endfunction
endclass
class hook_leaf extends hook_mid;
  int pre_leaf, post_leaf;
  function void pre_randomize(); pre_leaf++; endfunction
  function void post_randomize(); post_leaf++; endfunction
endclass
class hook_sibling extends hook_base;
  int pre_sibling, post_sibling;
  function void pre_randomize(); pre_sibling++; endfunction
  function void post_randomize(); post_sibling++; endfunction
endclass
class hook_empty;
  rand int value;
endclass
class hook_first extends hook_empty;
  int pre_calls, post_calls;
  function void pre_randomize(); pre_calls++; endfunction
  function void post_randomize(); post_calls++; endfunction
endclass
class hook_second extends hook_empty;
  int pre_calls, post_calls;
  function void pre_randomize(); pre_calls++; endfunction
  function void post_randomize(); post_calls++; endfunction
endclass
// Same basename in unrelated packages must never satisfy callback lookup.
package hook_left;
  class parent;
    rand int value;
    int pre_base, post_base;
    function void pre_randomize(); pre_base++; endfunction
    function void post_randomize(); post_base++; endfunction
  endclass
  class same_name extends parent; endclass
endpackage
package hook_right;
  class same_name;
    function void pre_randomize(); $fatal(1, "unrelated package pre"); endfunction
    function void post_randomize(); $fatal(1, "unrelated package post"); endfunction
  endclass
endpackage
module main;
  hook_base b;
  hook_mid m;
  hook_leaf l;
  hook_sibling s;
  hook_empty e;
  hook_first f;
  hook_second t;
  hook_left::same_name left;
  hook_left::parent lp;
  int evals, old_value;
  function hook_base receiver(); evals++; return b; endfunction
  initial begin
    l = new; m = new; s = new; f = new; t = new; left = new;
    b = l;
    if (!receiver().randomize()) $fatal(1, "leaf solve");
    if (evals != 1 || l.pre_leaf != 1 || l.post_leaf != 1 ||
        l.pre_mid != 0 || l.pre_base != 0 || l.post_base != 0)
      $fatal(1, "leaf hook dispatch");
    // The direct nonvirtual call must still choose the declared base.
    b.pre_randomize(); b.post_randomize();
    if (l.pre_base != 1 || l.post_base != 1 || l.pre_leaf != 1)
      $fatal(1, "direct hook call became virtual");
    b = m;
    if (!b.randomize() || m.pre_mid != 1 || m.post_base != 1 || m.pre_base != 0)
      $fatal(1, "independent nearest inherited hooks");
    b = s;
    if (!b.randomize() with { value == 7; }) $fatal(1, "sibling solve");
    if (s.pre_sibling != 1 || s.post_sibling != 1 || s.value != 7 ||
        s.pre_base != 0 || s.post_base != 0)
      $fatal(1, "sibling inline hooks");
    old_value = s.value;
    if (b.randomize() with { value == 99; }) $fatal(1, "unsat accepted");
    if (s.pre_sibling != 2 || s.post_sibling != 1 || s.value != old_value)
      $fatal(1, "failed solve hooks or writeback");
    if (!b.randomize(null)) $fatal(1, "checker failed");
    if (s.pre_sibling != 3 || s.post_sibling != 2 || s.value != old_value)
      $fatal(1, "checker skipped hooks or randomized state");
    if (!b.randomize(null) with { value == 7; }) $fatal(1, "inline checker");
    if (s.pre_sibling != 4 || s.post_sibling != 3)
      $fatal(1, "inline checker hooks");
    if (b.randomize(null) with { value == 99; }) $fatal(1, "unsat checker");
    if (s.pre_sibling != 5 || s.post_sibling != 3 || s.value != old_value)
      $fatal(1, "failed checker hooks");
    e = f;
    if (!e.randomize()) $fatal(1, "first solve");
    e = t;
    if (!e.randomize()) $fatal(1, "second solve");
    if (f.pre_calls != 1 || f.post_calls != 1 || t.pre_calls != 1 || t.post_calls != 1)
      $fatal(1, "multiple derived callbacks skipped");
    lp = left;
    if (!lp.randomize() || left.pre_base != 1 || left.post_base != 1)
      $fatal(1, "qualified inherited callback lookup");
    $display("PASSED");
  end
endmodule
