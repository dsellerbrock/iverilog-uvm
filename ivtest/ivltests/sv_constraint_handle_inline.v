// IEEE 1800-2017/2023 8.4, 11.4.5, 18.4, 18.6.2, 18.11.
// The inline bare name belongs to the randomized target; local:: names are
// caller handles. Root pre_randomize replaces the active handle before solving.
class inline_leaf;
  rand bit value;
  int pre_calls, post_calls;
  function void pre_randomize(); pre_calls++; endfunction
  function void post_randomize(); post_calls++; endfunction
endclass

class inline_root;
  rand inline_leaf active;
  inline_leaf replacement;
  bit replace_next;
  int pre_calls, post_calls;
  constraint c { active != null; active.value == 1; }
  function void pre_randomize();
    pre_calls++;
    if (replace_next) active = replacement;
  endfunction
  function void post_randomize(); post_calls++; endfunction
endclass

module main;
  inline_root r;
  inline_leaf active, expected, other, stale;
  initial begin
    r = new;
    active = new;
    expected = active;
    other = new;
    stale = new;
    r.active = stale;
    r.replacement = active;
    r.replace_next = 1;
    if (!r.randomize() with {
      active == local::active;
      active == local::expected;
      active != local::other;
      active != null;
    }) $fatal(1, "inline target/caller identity or replacement rejected");
    if (r.active !== active || active.value != 1 || stale.value != 0)
      $fatal(1, "replacement leaf not solved or stale leaf changed");
    if (r.pre_calls != 1 || r.post_calls != 1 ||
        active.pre_calls != 1 || active.post_calls != 1 ||
        stale.pre_calls != 0 || stale.post_calls != 0 ||
        other.pre_calls != 0 || other.post_calls != 0)
      $fatal(1, "replacement callback graph incorrect");

    active.value = 0;
    if (r.randomize() with { active == local::other; })
      $fatal(1, "distinct caller handle accepted as target identity");
    if (r.active !== active || active.value != 0 || stale.value != 0)
      $fatal(1, "inline failure changed handle or failed value rollback");
    if (r.pre_calls != 2 || r.post_calls != 1 ||
        active.pre_calls != 2 || active.post_calls != 1 ||
        stale.pre_calls != 0 || stale.post_calls != 0 ||
        other.pre_calls != 0 || other.post_calls != 0)
      $fatal(1, "failed inline solve committed post callbacks");
    $display("PASSED");
  end
endmodule
