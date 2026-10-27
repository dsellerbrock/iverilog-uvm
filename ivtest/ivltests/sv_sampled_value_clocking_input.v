// IEEE 1800-2017 16.5.1 and 16.9.3: sampled-value functions use the
// clocking input's #1step sample for the current and historical values.
module main;
  bit clk = 0;
  logic d = 0;
  logic undriven;
  int tick = 0;
  int fails = 0;

  always #5 clk = ~clk;
  clocking cb @(posedge clk);
    input #1step d;
    input #1step undriven;
    input mapped = d;
  endclocking

  initial begin
    #7 d = 1;
    #10 d = 0;
    #10 d = 1;
  end

  always_ff @(posedge clk) begin
    tick++;
    case (tick)
      1: begin
        if ($past(cb.d) !== 1'b0 || $past(cb.mapped) !== $past(d)
            || $past(cb.undriven) !== $past(undriven)) begin
          fails++;
          $display("FAILED -- first past=%b mapped=%b undriven=%b",
                   $past(cb.d), $past(cb.mapped), $past(cb.undriven));
        end
      end
      2: begin
        if ($past(cb.d) !== 1'b0 || $rose(cb.d) !== 1'b1
            || $past(cb.d + 2'b10) !== 2'd2
            || $past(cb.mapped) !== $past(d)) begin
          fails++;
          $display("FAILED -- second tick past=%b rose=%b expr=%b mapped=%b",
                   $past(cb.d), $rose(cb.d), $past(cb.d + 2'b10),
                   $past(cb.mapped));
        end
      end
      3: begin
        if ($past(cb.d) !== 1'b1 || $past(cb.d, 2) !== 1'b0
            || $fell(cb.d) !== 1'b1
            || $past(cb.d + 2'b10) !== 2'd3) begin
          fails++;
          $display("FAILED -- third tick past=%b past2=%b fell=%b expr=%b",
                   $past(cb.d), $past(cb.d, 2), $fell(cb.d),
                   $past(cb.d + 2'b10));
        end
      end
    endcase
  end

  initial begin
    #27;
    if (fails == 0) $display("PASSED");
    $finish(0);
  end
endmodule
