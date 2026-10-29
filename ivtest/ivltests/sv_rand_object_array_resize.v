// IEEE 1800-2017/2023 18.4: resize retains handles and appends null handles.
class resize_leaf;
  rand bit [7:0] value;
endclass

class resize_parent;
  rand resize_leaf children[];
  constraint size_c { children.size() == 2; }
endclass

module test;
  resize_parent item = new;
  resize_leaf original = new;
  initial begin
    item.children = new[1];
    item.children[0] = original;
    if (!item.randomize()) $fatal(1, "object handle array randomization failed");
    if (item.children.size() != 2 || item.children[0] != original
        || item.children[1] != null)
      $fatal(1, "array resize/handle preservation mismatch");
    $display("PASSED");
  end
endmodule
