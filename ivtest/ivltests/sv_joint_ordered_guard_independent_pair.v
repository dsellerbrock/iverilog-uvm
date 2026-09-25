class independent_pair_leaf;
  rand bit gate, x, y;
  constraint c {
    solve gate before x, y;
    if (gate) {
      x dist {0 := 1, 1 := 3};
      y dist {0 := 3, 1 := 1};
    }
  }
endclass

class independent_pair_root;
  rand independent_pair_leaf child;
  function new(); child = new; endfunction
endclass

module sv_joint_ordered_guard_independent_pair;
  independent_pair_root root;
  int active, x_ones, y_ones, inactive, inactive_x, inactive_y;
  initial begin
    root = new;
    root.srandom(32'h494e4450);
    repeat (2048) begin
      if (!root.randomize()) $fatal(1, "independent conditional pair failed");
      if (root.child.gate) begin
        active++;
        x_ones += root.child.x;
        y_ones += root.child.y;
      end else begin
        inactive++;
        inactive_x += root.child.x;
        inactive_y += root.child.y;
      end
    end
    if (active < 850 || active > 1200 ||
        x_ones < 600 || x_ones > 950 ||
        y_ones < 120 || y_ones > 400 ||
        inactive_x < 350 || inactive_x > 700 ||
        inactive_y < 350 || inactive_y > 700)
      $fatal(1, "marginals active=%0d x1=%0d y1=%0d inactive=%0d ix1=%0d iy1=%0d",
             active, x_ones, y_ones, inactive, inactive_x, inactive_y);
    $display("PASSED");
  end
endmodule
