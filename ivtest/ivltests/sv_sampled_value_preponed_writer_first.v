module main;
  bit clk = 0;
  int d = 0;
  int writes = 0;
  int fails = 0;

  always #5 clk = ~clk;
  default clocking cb @(posedge clk); endclocking

  // The writer is intentionally declared before the reader. Its blocking
  // write is visible in Active, but $past must retain the Preponed value.
  always @(posedge clk) begin
    d = writes + 1;
    writes++;
  end

  always @(posedge clk) begin
    if (writes == 2 && $past(d) !== 0) begin
      $display("FAIL: tick 2 $past(d)=%0d, expected 0", $past(d));
      fails++;
    end
    if (writes == 3 && $past(d) !== 1) begin
      $display("FAIL: tick 3 $past(d)=%0d, expected 1", $past(d));
      fails++;
    end
    if (writes == 2 && $past(d, 1, 1'b1, @(posedge clk)) !== 0) begin
      $display("FAIL: explicit-clock $past(d)=%0d, expected 0",
               $past(d, 1, 1'b1, @(posedge clk)));
      fails++;
    end
  end

  always @(posedge clk) begin : automatic_block
    automatic int local_value;
    local_value = writes + 1;
    if ($past(local_value) !== local_value) begin
      $display("FAIL: automatic $past(local_value)=%0d, current=%0d",
               $past(local_value), local_value);
      fails++;
    end
  end

  // This reader has no enclosing event control at the call site, so it uses
  // the default clocking block. It must still see the Preponed value.
  initial begin : default_clock_reader
    automatic int local_value;
    int tick;
    tick = 0;
    repeat (4) begin
      @(posedge clk);
      tick++;
      local_value = tick;
      if (tick == 2 && $past(d) !== 0) begin
        $display("FAIL: default-clock $past(d)=%0d, expected 0", $past(d));
        fails++;
      end
      if ($past(local_value) !== local_value) begin
        $display("FAIL: default-clock automatic $past=%0d, current=%0d",
                 $past(local_value), local_value);
        fails++;
      end
    end
  end

  initial begin
    repeat (4) @(posedge clk);
    #1;
    if (fails == 0)
      $display("PASSED");
    $finish;
  end
endmodule
