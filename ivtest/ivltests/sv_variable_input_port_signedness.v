// Widen variable actuals according to their own signedness before assigning
// them to unsigned input ports, including unknown sign bits in 4-state logic.
module variable_input_signedness_sink(
    input wire logic [7:0] signed_logic,
    input wire logic [7:0] unsigned_logic,
    input wire bit [7:0] signed_bit,
    input wire bit [7:0] unsigned_bit
);
endmodule

module sv_variable_input_port_signedness;
  logic signed [3:0] signed_logic;
  logic [3:0] unsigned_logic;
  bit signed [3:0] signed_bit;
  bit [3:0] unsigned_bit;
  bit failed;

  variable_input_signedness_sink dut(
      .signed_logic(signed_logic), .unsigned_logic(unsigned_logic),
      .signed_bit(signed_bit), .unsigned_bit(unsigned_bit));

  initial begin
    failed = 0;
    signed_logic = 4'bx001;
    unsigned_logic = 4'bx001;
    signed_bit = 4'b1001;
    unsigned_bit = 4'b1001;
    #1;
    if (dut.signed_logic !== 8'bxxxxx001) begin
      $display("FAIL signed logic: %b", dut.signed_logic);
      failed = 1;
    end
    if (dut.unsigned_logic !== 8'b0000x001) begin
      $display("FAIL unsigned logic: %b", dut.unsigned_logic);
      failed = 1;
    end
    if (dut.signed_bit !== 8'b11111001) begin
      $display("FAIL signed bit: %b", dut.signed_bit);
      failed = 1;
    end
    if (dut.unsigned_bit !== 8'b00001001) begin
      $display("FAIL unsigned bit: %b", dut.unsigned_bit);
      failed = 1;
    end
    if (failed) $fatal(1, "input-port signedness mismatch");
    $display("PASSED");
  end
endmodule
