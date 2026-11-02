// IEEE 1800-2017/2023 11.3.5, 18.5.6/18.5.5: a false rand guard
// short-circuits a state read through a null handle.
class rand_guard_leaf;
  int value = 5;
endclass

class rand_guard_item;
  rand int x;
  rand bit b;
  rand_guard_leaf h;
endclass

module main;
  rand_guard_item item = new;
  int ok;

  initial begin
    ok = item.randomize() with { b -> x == h.value; x == 13; };
    if (!ok || item.x != 13 || item.b != 0)
      $fatal(1, "implication rand guard failed: %0d %0d %0d",
             ok, item.x, item.b);

    ok = item.randomize() with { !b || x == h.value; x == 14; };
    if (!ok || item.x != 14 || item.b != 0)
      $fatal(1, "logical-or rand guard failed: %0d %0d %0d",
             ok, item.x, item.b);

    $display("PASSED");
  end
endmodule
