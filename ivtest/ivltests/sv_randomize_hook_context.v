// IEEE 1800-2017/2023 18.6.2, 18.6.3, 18.7: callbacks finish before
// inline caller-state capture; nested randomize calls own distinct frames.
class hook_context_base;
  rand int value;
  int limit, pre_calls, post_calls;
endclass
class hook_context_item #(int LIMIT = 9) extends hook_context_base;
  function void pre_randomize(); pre_calls++; limit = LIMIT; endfunction
  function void post_randomize(); post_calls++; endfunction
endclass
class recursive_hook;
  rand bit value;
  int depth, pre_calls, post_calls;
  recursive_hook nested;
  function void pre_randomize();
    pre_calls++;
    if (depth > 0) begin
      nested = new;
      nested.depth = depth - 1;
      if (!nested.randomize()) $fatal(1, "nested solve failed");
    end
  endfunction
  function void post_randomize(); post_calls++; endfunction
endclass
class checker_hook;
  rand int value;
  int pre_calls, post_calls;
  bit impossible;
  constraint c { value == 7; impossible == 0; }
  function void pre_randomize(); pre_calls++; value = 7; endfunction
  function void post_randomize(); post_calls++; endfunction
endclass
module main;
  hook_context_base b;
  hook_context_item #(9) a;
  hook_context_item #(13) c;
  recursive_hook r;
  checker_hook h;
  initial begin
    a = new; c = new;
    b = a;
    if (!b.randomize() with { value == local::b.limit; } || b.value != 9 ||
        b.pre_calls != 1 || b.post_calls != 1)
      $fatal(1, "inline slot captured before dynamic pre hook");
    b = c;
    if (!b.randomize() with { value == local::b.limit; } || b.value != 13 ||
        b.pre_calls != 1 || b.post_calls != 1)
      $fatal(1, "parameter specialization callback identity");
    r = new; r.depth = 2;
    if (!r.randomize()) $fatal(1, "recursive root solve");
    if (r.pre_calls != 1 || r.post_calls != 1 ||
        r.nested.pre_calls != 1 || r.nested.post_calls != 1 ||
        r.nested.nested.pre_calls != 1 || r.nested.nested.post_calls != 1)
      $fatal(1, "recursive callback frame/receiver corrupted");
    h = new; h.value = -1;
    if (!h.randomize(null) || h.value != 7 || h.pre_calls != 1 || h.post_calls != 1)
      $fatal(1, "checker pre side effect was skipped");
    h.value = -2; h.impossible = 1;
    if (h.randomize(null)) $fatal(1, "impossible checker accepted");
    if (h.value != 7 || h.pre_calls != 2 || h.post_calls != 1)
      $fatal(1, "failed checker lost pre side effect or called post");
    $display("PASSED");
  end
endmodule
