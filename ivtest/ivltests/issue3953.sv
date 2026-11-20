module issue3953_reducer;
  timeunit 1ns;
  timeprecision 1ns;
  bit clk;
  bit sig = 1;
  global clocking gc @(posedge clk); endclocking

  always #5 clk = !clk;
  assert property (@($global_clock) $future_gclk(sig))
    $display("PASS %0t", $time);
  else $fatal(1, "Unexpected failure at %0t", $time);
endmodule

module issue3953;
  timeunit 1ns;
  timeprecision 1ns;
  issue3953_reducer reducer();

  localparam logic [79:0] A = 80'hxz01_2345_6789_abcd_ef01;
  localparam logic [79:0] B = 80'hzx01_2345_6789_abcd_ef01;
  logic [79:0] source_value, future_value = A;
  logic signed [3:0] negative = -2;
  real future_real = 3.5;
  int current = 4;
  bit gclk, aclk, other, disabled, late_disable;
  int marker, begins, ends, failures, assumptions, covers, killed_passes, late_passes;
  int typed_passes;

  global clocking gc @(posedge gclk); endclocking
  initial begin
    #10;
    repeat (5) begin
      gclk = 1;
      #1 gclk = 0;
      #9;
    end
  end

  always @(posedge gclk) begin
    marker <= marker + 1;
    future_value <= marker == 1 ? A : B;
    future_real <= 4.5;
  end

  property mixed;
    @(posedge aclk) disable iff (disabled)
      (source_value === $future_gclk(future_value)) &&
      ($future_gclk(negative) < 0) &&
      $future_gclk(2'b10);
  endproperty

  check_mixed: assert property (mixed) begin
    begins++;
    $display("begin %0d %0t marker=%0d", begins, $time, marker);
    #26;
    ends++;
    $display("end %0d %0t", ends, $time);
  end else begin
    failures++;
    $display("fail %0d %0t marker=%0d", failures, $time, marker);
  end

  check_assume: assume property (@(posedge other) $future_gclk(negative) < 0) begin
    if ($time != 10 || marker != 1) $fatal(1, "Assumption action ran early");
    assumptions++;
  end
  else $fatal(1, "Unexpected failed assumption");

  check_cover: cover property (@(posedge other) $future_gclk(future_value) === A) begin
    if ($time != 10 || marker != 1) $fatal(1, "Cover action ran early");
    covers++;
  end

  check_kill: assert property (@(posedge other) $future_gclk(1'b1))
    killed_passes++;

  check_late_disable: assert property (@(posedge other) disable iff (late_disable)
                                       $future_gclk(1'b1))
    late_passes++;

  check_types: assert property (@(posedge other)
    ($future_gclk(future_real + const'(current)) == 8.5) &&
    ($future_gclk(const'(current)) == 5))
    typed_passes++;

  initial begin
    #1 source_value = A;
    #1 aclk = 1;                       // t=2, passes at 10
    #1 begin aclk = 0; source_value = B; other = 1; current <= 5; end
    #1 aclk = 1;                       // t=4, fails at 10
    #1 begin aclk = 0; source_value = A; current = 9; end
    #1 begin aclk = 1; disabled <= 1; end // t=6, disabled in Observed
    #1 begin aclk = 0; disabled = 0; end
    #1 begin
      $assertkill(0, check_mixed);     // t=8, both attempts already ended
      $assertkill(0, check_kill);      // stays off through the dispatch tick
      disabled = 1;
      late_disable = 1;               // stays true through the dispatch tick
    end
    #1 begin
      $asserton(0, check_mixed);
      disabled = 0;
      source_value = B;
    end
    #1 aclk = 1;                       // t=10, coincides with G, passes at 20
    #1 begin aclk = 0; source_value = A; end
    #1 aclk = 1;                       // t=12, fails at 20, action suppressed
    #1 aclk = 0;
    #1 $assertcontrol(9, 1, 1, 0, check_mixed);
    #7 begin
      $assertcontrol(8, 1, 1, 0, check_mixed);
      source_value = B;
    end
    #1 aclk = 1;                       // t=22, fails at 30
    #1 aclk = 0;
    #37;
    if (begins != 2 || ends != 2 || failures != 2 || assumptions != 1 || covers != 1)
      $fatal(1, "Wrong counts %0d %0d %0d %0d %0d",
             begins, ends, failures, assumptions, covers);
    if (killed_passes != 1 || late_passes != 1)
      $fatal(1, "A later Kill or disable iff canceled a completed attempt");
    if (typed_passes != 1)
      $fatal(1, "A typed future expression lost its source or global sample");
    $finish(0);
  end
endmodule
