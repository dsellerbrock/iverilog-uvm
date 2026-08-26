// Wake coalescing is restricted to proven-pure always_comb consumers.  An
// ordinary explicit event observer must still wake when storage changes,
// even when the producing evaluation restores the old value before yielding.
module sv_always_comb_observer_visibility;
  logic kick = 1'b0;
  logic pulse = 1'b0;
  logic observed_value = 1'b1;
  integer observer_runs = 0;

  always_comb begin
    pulse = kick;
    pulse = 1'b0;
  end

  always @(pulse) begin
    observer_runs = observer_runs + 1;
    observed_value = pulse;
  end

  initial begin
    #1;
    // Discard any implementation-specific time-zero initialization event.
    observer_runs = 0;
    observed_value = 1'b1;

    kick = 1'b1;
    #1;
    if (pulse !== 1'b0 || observer_runs != 1 ||
        observed_value !== 1'b0)
      $display("FAILED: pulse=%b runs=%0d observed=%b",
               pulse, observer_runs, observed_value);
    else
      $display("PASSED");
    $finish(0);
  end
endmodule
