class proven_guard_leaf;
  rand bit [1:0] value;
  rand bit gate;
  bit expected_gate;

  constraint guarded_c {
    gate == expected_gate;
    if (gate) value dist {2'd0 := 1, 2'd1 := 9};
    else      value dist {2'd2 := 1, 2'd3 := 9};
  }
endclass

class proven_guard_peer;
  rand bit [1:0] value;
  rand bit gate;
endclass

class proven_guard_root;
  rand proven_guard_leaf a;
  rand proven_guard_peer b;
  constraint coupled_c {
    a.gate == b.gate;
    a.value == b.value;
  }
  function new(); a = new; b = new; endfunction
endclass

module sv_joint_proven_guard_positive;
  proven_guard_root root;
  int high_count;
  initial begin
    root = new;
    for (int mode = 0; mode < 2; mode++) begin
      high_count = 0;
      root.a.expected_gate = mode;
      for (int i = 0; i < 300; i++) begin
        if (!root.randomize()) $fatal(1, "proved guarded joint solve failed");
        if (root.a.gate != mode || root.b.gate != mode ||
            root.a.value != root.b.value)
          $fatal(1, "joint guard or coupling was lost");
        if (mode) begin
          if (!(root.a.value inside {2'd0, 2'd1}))
            $fatal(1, "inactive else dist constrained an active branch");
          if (root.a.value == 2'd1) high_count++;
        end else begin
          if (!(root.a.value inside {2'd2, 2'd3}))
            $fatal(1, "inactive then dist constrained an active branch");
          if (root.a.value == 2'd3) high_count++;
        end
      end
      if (high_count < 240 || high_count > 292)
        $fatal(1, "active guarded dist lost its 9:1 weight: %0d/300", high_count);
    end
    $display("PASSED");
    $finish(0);
  end
endmodule
