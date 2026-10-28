module top;
  bit clk;
  logic [1:0] data;
  int tick, errors;

  always #5 clk = ~clk;

  always @(posedge clk) begin
    tick++;
    if (tick == 3) begin
      for (int i = 0; i < 2; i++) begin
        if ($past(data[i]) !== ((i == 0) ? 1'b1 : 1'b0)) errors++;
      end
      if (errors) $fatal(1, "automatic expression errors=%0d", errors);
      $display("ISSUE1360_PAST_AUTOMATIC_INDEX_PASSED");
      $finish(0);
    end
  end

  initial begin
    data = 0;
    @(negedge clk) data = 2'b01;
    @(negedge clk) data = 2'b10;
  end
endmodule
