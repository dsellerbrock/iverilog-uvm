// M8 increment 2d: clocking skew APPLICATION (IEEE 1800-2017 14.4).
//
// Previously skews were parsed and discarded. Now:
//   - `input #0 s`  samples in the Observed position: the value AFTER
//     the NBA region of the edge step, so an NBA update landing at the
//     edge IS seen by that edge's sample (unlike #1step, which samples
//     the value from before the step).
//   - `input #d s`  samples the value the signal held d time units
//     before the edge (via a transport-delayed shadow).
//   - `output #d s` lands the drive d time units after the event.
//   - `default input/output` skews apply to items without their own.
//   - #1step / unskewed behavior is unchanged (Preponed sample).

`timescale 1ns/1ns

module m8_clocking_skew_test;
  logic clk = 0;
  logic [7:0] s_1step = 8'h01;
  logic [7:0] s_zero  = 8'h02;
  logic [7:0] s_two   = 8'h0A;
  logic [7:0] o_three = 8'h00;
  logic [7:0] s_dflt  = 8'h05;
  int errors = 0;

  always #5 clk = ~clk;   // edges at 5, 15, 25, ...

  clocking cb @(posedge clk);
    input        s_1step;   // default #1step
    input  #0    s_zero;
    input  #2    s_two;
    output #3    o_three;
  endclocking

  // default input skew applies to items without their own skew
  clocking dcb @(posedge clk);
    default input #0 output #0;
    input s_dflt;
  endclocking

  // NBA driver: land new values exactly ON the t=15 edge, so the
  // #1step sample misses them and the #0 sample sees them.
  initial begin
    #15;                    // Active of t=15 (the edge step)
    s_1step <= 8'h11;       // NBA: lands at t=15 after Active
    s_zero  <= 8'h22;
    s_dflt  <= 8'h55;
  end

  task check(input bit ok, input string what);
    if (!ok) begin
      errors++;
      $display("FAILED: %s", what);
    end
  endtask

  initial begin
    // s_two timeline for the #2 skew: value at (edge - 2).
    // Set 0x0B at t=12 -> at t=15-2=13 the value is 0x0B.
    #12 s_two = 8'h0B;
    // Then 0x0C at t=14 (inside the 2ns window before the t=15
    // edge): must NOT be seen by the t=15 sample.
    #2 s_two = 8'h0C;

    @(cb);                  // edge at t=15
    check(cb.s_1step == 8'h01,
          "#1step misses the NBA landing at the edge");
    check(cb.s_zero == 8'h22,
          "#0 sees the NBA landing at the edge (Observed)");
    check(cb.s_two == 8'h0B,
          "#2 samples the value from 2ns before the edge");
    check(dcb.s_dflt == 8'h55,
          "default input #0 applies to unskewed item");

    // Raw values now settled; next edge samples them everywhere.
    @(cb);                  // edge at t=25
    check(cb.s_1step == 8'h11, "#1step catches up next edge");
    check(cb.s_two == 8'h0C, "#2 catches up (value from t=23)");

    // Output skew: drive after @(cb) at t=25 lands at t=25+3.
    cb.o_three <= 8'h77;
    #2;                     // t=27: not yet
    check(o_three == 8'h00, "output #3 has not landed at +2");
    #2;                     // t=29: landed at t=28
    check(o_three == 8'h77, "output #3 lands 3ns after the event");

    // Buffered (between-edge) drive with output skew: issued now
    // (t=29), lands at the t=35 edge +3 = t=38.
    cb.o_three <= 8'h88;
    @(posedge clk);         // t=35
    #2;                     // t=37: not yet
    check(o_three == 8'h77, "buffered output #3 not landed at edge+2");
    #2;                     // t=39: landed at t=38
    check(o_three == 8'h88, "buffered output #3 lands at edge+3");

    if (errors == 0)
      $display("PASSED: all m8 clocking skew checks");
    else
      $display("FAILED: %0d m8 clocking skew checks", errors);
    $finish(0);
  end
endmodule
