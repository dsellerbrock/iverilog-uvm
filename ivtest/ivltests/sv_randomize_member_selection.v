// IEEE 1800-2017/2023 18.6.2, 18.8 and 18.11.
package member_selection_state;
  typedef struct { int value; } element_t;
  typedef struct { element_t values[$]; } collection_t;
  collection_t collections[$] = '{'{'{'{3}}}};
endpackage
class selected_item;
  rand bit value = 1;
  int pre_calls, post_calls;
  function void pre_randomize(); pre_calls++; endfunction
  function void post_randomize(); post_calls++; endfunction
endclass
class selected_root;
  rand selected_item enabled;
  selected_item manual;
  rand int x;
  int pre_calls, post_calls;
  function new(); enabled = new; manual = new; endfunction
  function void pre_randomize(); pre_calls++; endfunction
  function void post_randomize(); post_calls++; endfunction
endclass
module main;
  import member_selection_state::*;
  selected_root root = new;
  selected_item alias_handle;
  int selected = 0;
  initial begin
    root.enabled.rand_mode(0);
    if (!root.randomize()) $fatal(1, "disabled handle solve failed");
    if (root.enabled.pre_calls != 0 || root.manual.pre_calls != 0)
      $fatal(1, "disabled or non-rand handle got callbacks");
    root.enabled.rand_mode(1);
    alias_handle = root.enabled;
    alias_handle.rand_mode(0);
    if (!root.randomize()) $fatal(1, "disabled child fields solve failed");
    if (root.enabled.pre_calls != 1 || root.enabled.post_calls != 1
        || root.enabled.value != 1)
      $fatal(1, "enabled object without active fields missed callbacks");
    if (!root.randomize(manual)) $fatal(1, "explicit non-rand handle rejected");
    if (root.manual.pre_calls != 1 || root.manual.post_calls != 1
        || root.enabled.pre_calls != 1 || root.enabled.post_calls != 1)
      $fatal(1, "explicit root selection applied incorrectly");
    if (!root.randomize(null)) $fatal(1, "checker failed");
    if (root.pre_calls != 4 || root.post_calls != 4
        || root.enabled.pre_calls != 1 || root.manual.pre_calls != 1)
      $fatal(1, "checker selector leaked or suppressed root callbacks");
    if (!root.randomize() with { x == 3; }) $fatal(1, "default with solve");
    if (root.enabled.pre_calls != 2 || root.enabled.post_calls != 2)
      $fatal(1, "default with member callbacks");
    if (!root.randomize(x) with { x == 4; }) $fatal(1, "explicit with solve");
    if (!root.randomize(null) with { x == 4; }) $fatal(1, "checker with solve");
    if (root.enabled.pre_calls != 2 || root.enabled.post_calls != 2 || root.x != 4)
      $fatal(1, "scalar or checker with selection reached child");
    if (!root.randomize(enabled) with { x == 4; }) $fatal(1, "explicit child with");
    if (root.enabled.pre_calls != 3 || root.enabled.post_calls != 3)
      $fatal(1, "explicit child with callbacks");
    if (!root.randomize() with {
      foreach (collections[selected].values[i]) x == collections[selected].values[i].value;
    }) $fatal(1, "with objects solve");
    if (root.enabled.pre_calls != 4 || root.enabled.post_calls != 4 || root.x != 3)
      $fatal(1, "with objects callbacks or capture");
    if (root.randomize() with { x == 0; x == 1; }) $fatal(1, "UNSAT accepted");
    if (root.enabled.pre_calls != 5 || root.enabled.post_calls != 4
        || root.pre_calls != 10 || root.post_calls != 9 || root.x != 3
        || root.manual.pre_calls != 1 || root.manual.post_calls != 1)
      $fatal(1, "with failure callback barrier or rollback");
    $display("PASSED");
  end
endmodule
