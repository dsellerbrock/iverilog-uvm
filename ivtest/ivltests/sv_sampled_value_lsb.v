module main;
  bit clk;
  logic [1:0] value;
  int tick, errors;

  always #5 clk = ~clk;

  always @(posedge clk) begin
    tick++;
    if (tick == 2 && $rose(value)) begin
      errors++;
      $display("FAILED -- $rose(value) counted an MSB-only change");
    end
    if (tick == 3 && !$rose(value)) begin
      errors++;
      $display("FAILED -- $rose(value) missed an LSB rise");
    end
    if (tick == 4 && !$fell(value)) begin
      errors++;
      $display("FAILED -- $fell(value) missed an LSB fall");
    end
    if (tick == 5) begin
      if (errors) $fatal(1, "LSB value-change errors=%0d", errors);
      $display("PASSED");
      $finish(0);
    end
  end

  initial begin
    value = 0;
    @(negedge clk) value = 2'b10;
    @(negedge clk) value = 2'b11;
    @(negedge clk) value = 2'b10;
  end
endmodule
