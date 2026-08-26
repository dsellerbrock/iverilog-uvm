// A proven-pure always_comb evaluation retains pure combinational consumers
// until its final values are known. If a synchronous VPI value-change
// callback finishes simulation after one such consumer has been retained,
// that consumer must still be released as pre-finish work. The ordinary
// consumer is a control: Icarus already drains work scheduled before finish
// in the current time slot, so the pure-comb optimization must be transparent.
module pure_comb_finish_cb;
  logic source = 1'b0;
  logic intermediate = 1'b0;
  logic finish_signal = 1'b0;
  logic pure_result = 1'b0;
  logic ordinary_result = 1'b0;

  always_comb begin
    intermediate = source;
    finish_signal = source;
  end

  always_comb begin
    pure_result = intermediate;
  end

  always @* begin
    ordinary_result = intermediate;
  end

  initial begin
    $finish_on_one(finish_signal, pure_result, ordinary_result);
    #1 source = 1'b1;
  end

  final begin
    if (pure_result === 1'b1 && ordinary_result === 1'b1)
      $display("PASSED: pure=%b ordinary=%b", pure_result, ordinary_result);
    else
      $display("FAILED: pure=%b ordinary=%b", pure_result, ordinary_result);
  end
endmodule
