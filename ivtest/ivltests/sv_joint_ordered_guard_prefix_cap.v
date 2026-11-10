class prefix_cap_leaf;
  rand bit [10:0] gate;
  rand bit x, y;
  constraint c {
    solve gate before x, y;
    if (gate[0]) {
      x dist {0 := 1, 1 := 3};
      y dist {0 := 3, 1 := 1};
    }
  }
endclass

class prefix_cap_root;
  rand prefix_cap_leaf child;
  function new(); child = new; endfunction
endclass

module sv_joint_ordered_guard_prefix_cap;
  prefix_cap_root root;
  initial begin
    root = new;
    if (!root.randomize()) $fatal(1, "oversize guard prefix failed");
    $display("PASSED");
  end
endmodule
