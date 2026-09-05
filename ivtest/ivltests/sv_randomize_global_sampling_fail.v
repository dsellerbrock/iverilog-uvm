// IEEE 1800-2017 18.5.9/18.5.10; IEEE 1800-2023 18.5.8/18.5.9.
// Unsupported joint distributions fail atomically; no prefix sampling.
class leaf;
  rand bit value;
endclass
class bounded_root;
  rand bit [10:0] value;
  rand leaf child;
  int limit = 1023;
  int posts;
  function new(); child = new; endfunction
  function void post_randomize(); posts++; endfunction
  constraint c { limit >= 0; value <= limit; child.value == 0; }
endclass
class sized_root;
  rand bit data[];
  rand leaf child;
  int low_bound, high_bound;
  int posts;
  function new(); child = new; data = new[2]; data[0]=1; data[1]=0; endfunction
  function void post_randomize(); posts++; endfunction
  constraint c { data.size() inside {[low_bound:high_bound]}; child.value == 0; }
endclass
class weighted_root;
  rand bit value;
  rand leaf child;
  function new(); child = new; endfunction
  constraint c { value dist {0 := 1, 1 := 2}; child.value <= value; }
endclass
class ordered_root;
  rand bit value, other;
  rand leaf child;
  function new(); child = new; endfunction
  constraint c { solve value before other; child.value <= other; other <= value; }
endclass
module main;
  bounded_root r = new;
  sized_root s = new;
  weighted_root w = new;
  ordered_root o = new;
  bit [10:0] before_value;
  bit before_child;
  initial begin
    r.srandom(53); r.child.srandom(59);
    if (!r.randomize() || r.value > 1023 || r.posts != 1)
      $fatal(1, "exactly 1024 tuples did not pass");
    before_value=r.value; before_child=r.child.value;
    r.limit=1024;
    if (r.randomize() || r.value != before_value || r.child.value != before_child || r.posts != 1)
      $fatal(1, "joint cap failure sampled a prefix or changed values/posts");
    r.limit=-1;
    if (r.randomize() || r.posts != 1) $fatal(1, "negative-domain failure changed callbacks");
    s.low_bound=1; s.high_bound=2;
    if (s.randomize() || s.data.size()!=2 || s.data[0]!=1 || s.data[1]!=0 || s.posts)
      $fatal(1, "ambiguous size failure changed array/posts");
    s.low_bound=65537; s.high_bound=65537;
    if (s.randomize() || s.data.size()!=2 || s.posts)
      $fatal(1, "unsupported fixed size silently clamped");
    if (!w.randomize() || w.child.value > w.value)
      $fatal(1, "supported weighted graph failed or broke its hard relation");
    if (o.randomize()) $fatal(1, "ordered graph silently used uniform tuples");
    $display("PASSED");
  end
endmodule
