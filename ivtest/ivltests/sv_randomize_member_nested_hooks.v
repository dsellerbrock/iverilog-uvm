// IEEE 1800-2017/2023 18.6.2/18.6.3: member callbacks use independent
// automatic frames, including explicit randomization nested in a callback.
class nested_callback_leaf;
  rand bit [3:0] value;
  int pre_calls, post_calls;
  constraint c { value == 7; }
  function void pre_randomize(); pre_calls++; endfunction
  function void post_randomize(); post_calls++; endfunction
endclass
class nested_callback_actor;
  rand nested_callback_leaf child;
  nested_callback_leaf helper;
  int pre_calls, post_calls;
  function new(); child = new; helper = new; endfunction
  function void pre_randomize();
    int saved = 100 + pre_calls;
    pre_calls++;
    if (!helper.randomize()) $fatal(1, "nested pre solve failed");
    if (saved != 99 + pre_calls || helper.pre_calls != pre_calls + post_calls
        || helper.post_calls != pre_calls + post_calls)
      $fatal(1, "nested pre frame or callback count lost");
  endfunction
  function void post_randomize();
    int saved = 200 + post_calls;
    post_calls++;
    if (!helper.randomize(null)) $fatal(1, "nested post checker failed");
    if (saved != 199 + post_calls) $fatal(1, "nested post frame lost");
  endfunction
endclass
class nested_callback_root;
  rand nested_callback_actor actor;
  rand nested_callback_leaf removed;
  bit reject;
  constraint c { reject == 0; }
  function new(); actor = new; removed = new; endfunction
  function void pre_randomize(); removed = null; endfunction
endclass
module main;
  nested_callback_root root = new;
  nested_callback_leaf removed;
  initial begin
    removed = root.removed;
    if (!root.randomize()) $fatal(1, "outer solve failed");
    if (removed.pre_calls != 0 || removed.post_calls != 0)
      $fatal(1, "detached pending member received callbacks");
    if (root.actor.pre_calls != 1 || root.actor.post_calls != 1
        || root.actor.child.pre_calls != 1 || root.actor.child.post_calls != 1
        || root.actor.helper.pre_calls != 2 || root.actor.helper.post_calls != 2)
      $fatal(1, "nested member callback counts");
    root.reject = 1;
    if (root.randomize()) $fatal(1, "outer failure accepted");
    if (root.actor.pre_calls != 2 || root.actor.post_calls != 1
        || root.actor.child.pre_calls != 2 || root.actor.child.post_calls != 1
        || root.actor.helper.pre_calls != 3 || root.actor.helper.post_calls != 3)
      $fatal(1, "nested success was confused with outer failure");
    root.reject = 0;
    if (!root.randomize()) $fatal(1, "later success rejected");
    if (root.actor.pre_calls != 3 || root.actor.post_calls != 2
        || root.actor.child.pre_calls != 3 || root.actor.child.post_calls != 2
        || root.actor.helper.pre_calls != 5 || root.actor.helper.post_calls != 5)
      $fatal(1, "failed call left stale callback state");
    $display("PASSED");
  end
endmodule
