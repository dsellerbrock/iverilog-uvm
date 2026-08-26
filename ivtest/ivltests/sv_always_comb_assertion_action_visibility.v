// An immediate assertion action is observable behavior, so the containing
// always_comb process is not a pure waiter.  It must run once at time zero and
// once more when the source makes a real 0->1->0 intermediate transition.
module sv_always_comb_assertion_action_visibility;
  logic kick = 1'b0;
  logic pulse = 1'b0;

  always_comb begin
    pulse = kick;
    pulse = 1'b0;
  end

  always_comb begin : assertion_observer
    assert (pulse && !pulse)
      else $display("ASSERT_ACTION");
  end

  initial begin
    #1;
    kick = 1'b1;
    #1;
    $display("PASSED");
    $finish(0);
  end
endmodule
