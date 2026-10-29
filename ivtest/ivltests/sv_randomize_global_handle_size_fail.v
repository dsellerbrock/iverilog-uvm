// IEEE 1800-2017/2023 18.4: retain class handles during rand array resize;
// newly added elements are null and are not constructed by randomize().
class size_leaf;
  rand bit [7:0] value;
endclass
class size_root;
  rand size_leaf items[];
  constraint c { items.size() == 2; }
endclass
module main;
  size_root r = new;
  size_leaf saved;
  initial begin
    r.items = new[1];
    saved = new;
    r.items[0] = saved;
    if (!r.randomize()) $fatal(1, "class-handle array resize failed");
    if (r.items.size() != 2 || r.items[0] != saved || r.items[1] != null)
      $fatal(1, "array resize did not retain handle and null-initialize new entry");
    $display("PASSED");
  end
endmodule
