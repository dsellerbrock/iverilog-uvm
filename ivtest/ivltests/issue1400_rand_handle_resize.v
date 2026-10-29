// IEEE 1800-2017/2023 18.4: retained class handles survive rand array resize;
// added elements are null and randomize() does not allocate class objects.
class issue1400_leaf;
  rand bit [7:0] value;
endclass

class issue1400_parent;
  rand issue1400_leaf children[];
  constraint size_c { children.size() == 2; }
endclass

module main;
  issue1400_parent item;
  issue1400_leaf original;
  initial begin
    item = new;
    original = new;
    item.children = new[1];
    item.children[0] = original;
    if (!item.randomize()) $fatal(1, "object handle array randomization failed");
    if (item.children.size() != 2 || item.children[0] != original ||
        item.children[1] != null)
      $fatal(1, "array resize/handle preservation mismatch");
    $display("PASSED");
  end
endmodule
