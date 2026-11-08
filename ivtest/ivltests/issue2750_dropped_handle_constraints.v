class issue2750_leaf;
  rand bit [3:0] value;
  int bad;
  constraint leaf_c { value == 9; bad == 0; }
endclass

class issue2750_root;
  rand issue2750_leaf items[];
  int wanted;
  constraint size_c { items.size == wanted; }
endclass

module test;
  issue2750_root root = new;
  issue2750_leaf retained = new;
  issue2750_leaf dropped = new;
  initial begin
    root.items = '{retained, dropped};
    dropped.bad = 1;
    root.wanted = 1;
    if (!root.randomize()) $fatal(1, "randomize failed with dropped object");
    if (root.items.size() != 1 || root.items[0] != retained
        || retained.value != 9 || dropped.bad != 1)
      $fatal(1, "wrong retained handle or randomized value");
    $display("PASSED");
  end
endmodule
