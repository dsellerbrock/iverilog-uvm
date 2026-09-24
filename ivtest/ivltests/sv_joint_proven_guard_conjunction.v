class conjunction_guard_leaf;
  rand bit first, second;
  rand bit [1:0] value;
  constraint c {
    first != second;
    if (first)
      if (second)
        value dist {2'd0 := 1, 2'd1 := 9};
  }
endclass

class conjunction_guard_root;
  rand conjunction_guard_leaf a, b;
  constraint coupled_c {a.value == b.value; a.value == 2'd2;}
  function new(); a = new; b = new; endfunction
endclass

module sv_joint_proven_guard_conjunction;
  conjunction_guard_root root;
  initial begin
    root = new;
    repeat (20) begin
      if (!root.randomize()) $fatal(1, "jointly inactive nested guard rejected");
      if (root.a.first == root.a.second ||
          root.b.first == root.b.second ||
          root.a.value != 2 || root.b.value != 2)
        $fatal(1, "jointly inactive dist constrained its subject");
    end
    $display("PASSED");
    $finish(0);
  end
endmodule
