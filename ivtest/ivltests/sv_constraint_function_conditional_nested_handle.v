// IEEE 1800-2017/2023: conditional member access, constraint guards and rollback.
class review_leaf;
  int x;
endclass
class review_node;
  review_leaf child;
endclass
class review_holder;
  rand bit pick;
  rand int result;
  review_node left;
  review_node right;
  constraint c { result == (pick ? left.child : right.child).x; }
endclass
module test;
  review_holder h;
  review_node node;
  review_leaf leaf;
  int ok;
  initial begin
    h = new; node = new; leaf = new; leaf.x = 7;
    node.child = leaf; h.left = node; h.right = null; h.result = 31;
    ok = h.randomize() with { pick == 1; };
    if (ok != 1 || h.pick != 1 || h.result != 7)
      $fatal(1, "inactive invalid nested branch affected solve ok=%0d pick=%0d result=%0d", ok, h.pick, h.result);
    leaf.x = 12;
    ok = h.randomize() with { pick == 1; };
    if (ok != 1 || h.pick != 1 || h.result != 12)
      $fatal(1, "refreshed valid left branch ok=%0d pick=%0d result=%0d", ok, h.pick, h.result);
    h.result = 37;
    ok = h.randomize() with { pick == 0; };
    if (ok != 0 || h.pick != 1 || h.result != 37)
      $fatal(1, "active invalid right branch/rollback ok=%0d pick=%0d result=%0d", ok, h.pick, h.result);
    h.left = null; h.right = node; leaf.x = 19;
    ok = h.randomize() with { pick == 0; };
    if (ok != 1 || h.pick != 0 || h.result != 19)
      $fatal(1, "inactive invalid left branch affected solve ok=%0d pick=%0d result=%0d", ok, h.pick, h.result);
    h.result = 41;
    ok = h.randomize() with { pick == 1; };
    if (ok != 0 || h.pick != 0 || h.result != 41)
      $fatal(1, "active invalid left branch/rollback ok=%0d pick=%0d result=%0d", ok, h.pick, h.result);
    $display("PASSED");
  end
endmodule
