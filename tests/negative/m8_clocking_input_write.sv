// M8-2a negative: writing an input clockvar must be a compile error.
// IEEE 1800-2017 14.3: input clocking signals are sampled, not
// driven. The alias model silently wrote the raw signal.
// EXPECT-FAIL-COMPILE
module m8_clocking_input_write;
  logic clk = 0;
  logic [7:0] din;

  clocking cb @(posedge clk);
    input din;
  endclocking

  initial begin
    cb.din <= 8'hff;   // error: cannot drive an input clockvar
  end
endmodule
