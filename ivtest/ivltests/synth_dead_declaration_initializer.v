`begin_keywords "1800-2012"

module main(input logic a, input logic b);
  // The initializer is a real initial assignment in simulation, but its only
  // output has no synthesis consumer. OpenTitan uses this idiom to consume
  // inputs in a disabled generate branch.
  logic unused_inputs = a & b;

  (* ivl_synthesis_off *)
  initial begin
    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords
