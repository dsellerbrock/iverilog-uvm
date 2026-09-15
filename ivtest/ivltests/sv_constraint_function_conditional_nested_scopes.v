// IEEE 1800-2017/2023: conditional member access, constraint guards and rollback.
class scope_leaf;
  int x;
endclass
class scope_node;
  scope_leaf child;
endclass
class scope_holder;
  rand bit pick;
  rand int guarded_result;
  rand int soft_result;
  scope_node left;
  scope_node right;
  bit enable;
  constraint guarded_c {
    enable -> guarded_result == (pick ? left.child : right.child).x;
  }
  constraint soft_c {
    soft soft_result == (pick ? left.child : right.child).x;
  }
endclass
module test;
  scope_holder h;
  scope_node node;
  scope_leaf leaf;
  int ok;
  initial begin
    h = new; node = new; leaf = new; leaf.x = 7;
    node.child = leaf; h.left = node; h.right = null;
    h.enable = 0; h.guarded_result = 31; h.soft_result = 37;
    ok = h.randomize() with { pick == 0; guarded_result == 13; soft_result == 17; };
    if (ok != 1 || h.pick != 0 || h.guarded_result != 13 || h.soft_result != 17)
      $fatal(1, "inactive outer guard/optional soft validity ok=%0d pick=%0d guarded=%0d soft=%0d",
             ok, h.pick, h.guarded_result, h.soft_result);
    h.enable = 1;
    ok = h.randomize() with { pick == 1; soft_result == 21; };
    if (ok != 1 || h.pick != 1 || h.guarded_result != 7 || h.soft_result != 21)
      $fatal(1, "active outer guard valid branch ok=%0d pick=%0d guarded=%0d soft=%0d",
             ok, h.pick, h.guarded_result, h.soft_result);
    $display("PASSED");
  end
endmodule
