module main;
  logic clk0=0, clk1=0, w=0, x=0, y=0, z=0, q=0;
  integer failures=0, hits=0, explicit_hits=0;
  integer passes_at_55=0, passes_at_125=0, passes_at_185=0;

  always #5 clk0=~clk0;
  always #7 clk1=~clk1;

  p: assert property (
      @(posedge clk0) w ##1 (x ##1 @(posedge clk1) y) ##1 z |=> q) begin
    case ($time)
      55: passes_at_55++;
      125: passes_at_125++;
      185: passes_at_185++;
    endcase
  end else begin
    if ($time != 125) $fatal(1, "Unexpected assertion failure at %0t", $time);
    failures++;
  end

  c: cover property (
      @(posedge clk0) w ##1 (x ##1 @(posedge clk1) y) ##1 z |=> q) begin
    if ($time != 55) $fatal(1, "Unexpected cover hit at %0t", $time);
    hits++;
  end

  explicit_clocks: cover property (
      @(posedge clk0) w ##1 x ##1 @(posedge clk1) y ##1 @(posedge clk0) z
      |=> @(posedge clk0) q) begin
    if ($time != 55) $fatal(1, "Unexpected explicit-clock hit at %0t", $time);
    explicit_hits++;
  end

  task automatic attempt(input bit z_value, input bit q_value);
    w=1;
    #10 begin w=0; x=1; end
    #10 begin x=0; y=1; end
    #10 begin y=0; z=z_value; end
    #10 begin z=0; q=q_value; end
    #10 q=0;
  endtask

  initial begin
    #1 $assertvacuousoff(0, c, explicit_clocks);

    // Both clocks tick at 35. z is sampled at 45 and q at 55.
    #9 attempt(1, 1);
    #20 attempt(1, 0);
    #20 attempt(0, 0);

    #10;
    if (failures != 1 || hits != 1 || explicit_hits != 1)
      $fatal(1, "Expected one failure and one hit per cover. Got %0d, %0d, %0d",
             failures, hits, explicit_hits);
    // w is false on each of these ticks, yielding one vacuous pass for
    // the new attempt. The older attempt passes with q at 55, fails at
    // 125, and passes vacuously with false z at 185.
    if (passes_at_55 != 2 || passes_at_125 != 1 || passes_at_185 != 2)
      $fatal(1, "Expected pass counts 2, 1, 2. Got %0d, %0d, %0d",
             passes_at_55, passes_at_125, passes_at_185);
    $display("PASSED");
    $finish(0);
  end
endmodule
