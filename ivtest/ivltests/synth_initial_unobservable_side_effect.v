`begin_keywords "1800-2012"

// An initial process may be deleted during synthesis when it consists only of
// side-effect-free assignments to unobservable signals. A system task in the
// same block is observable: it must keep the process alive even though the
// assignment itself has no synthesis consumer.
module synth_initial_unobservable_side_effect;
  logic unobserved;

  initial begin
    unobserved = 1'b1;
    $display("SIDE_EFFECT_SURVIVED");
  end
endmodule

`end_keywords
