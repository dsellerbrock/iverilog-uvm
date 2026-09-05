// IEEE 1800-2017 18.5.13 / 1800-2023 18.5.12: guards exclude ERROR.
// A bare null handle is a valid identity operand; dereferencing it is ERROR.
class guard_leaf;
  rand bit value;
  guard_leaf peer;
endclass

class guard_root;
  rand bit [7:0] payload;
  rand guard_leaf child;
  rand guard_leaf items[];
  guard_leaf absent;
  bit unguarded;
  int pre_calls, post_calls;
  function new();
    child = new;
    items = new[2];
    items[0] = child;
  endfunction
  function void pre_randomize(); pre_calls++; endfunction
  function void post_randomize(); post_calls++; endfunction
  constraint c {
    payload == 42;
    if (!unguarded) {
      if (absent != null) absent.peer == child;
      (absent != null) -> absent.peer == child;
      (absent == null) || (absent.peer == child);
      !(absent != null && absent.peer != child);
      if (child != null) child.value == 1;
      foreach (items[i]) if (items[i] != null) {
        items[i].value == 1;
        items[i].peer == null;
      }
    } else {
      // This must fail explicitly: absent.peer is not the null handle value.
      absent.peer == null;
    }
  }
endclass

module main;
  guard_root r;
  guard_leaf original;
  initial begin
    r = new;
    original = r.child;
    if (!r.randomize()) $fatal(1, "guarded null dereference rejected");
    if (r.payload != 42 || r.child.value != 1 ||
        r.child !== original || r.items[0] !== original || r.items[1] !== null ||
        r.absent !== null || r.pre_calls != 1 || r.post_calls != 1)
      $fatal(1, "guarded solve changed handles, values, or callbacks");

    r.payload = 91;
    r.child.value = 0;
    r.unguarded = 1;
    if (r.randomize()) $fatal(1, "unguarded null dereference accepted");
    if (r.payload != 91 || r.child.value != 0 ||
        r.child !== original || r.items[0] !== original || r.items[1] !== null ||
        r.absent !== null || r.pre_calls != 2 || r.post_calls != 1)
      $fatal(1, "unguarded failure did not roll back values or skipped post");
    $display("PASSED");
  end
endmodule
