// IEEE 1800-2017 16.9.2: a member selected from an unpacked struct
// localparam is an integral constant expression and may be used in cycle
// delay and consecutive-repetition bounds. OpenTitan rstmgr uses this exact
// nested edge_bounds_t shape and these PeriCycles values.
interface unpacked_struct_parameter_delay_if (
  input logic clk,
  input logic req_range,
  input logic req_repeat,
  input logic hold_repeat,
  input logic ack_range,
  input logic ack_repeat
);
  typedef struct {
    int min;
    int max;
  } bounds_t;

  typedef struct {
    bounds_t fall;
    bounds_t rise;
  } edge_bounds_t;

  localparam edge_bounds_t PeriCycles =
      '{fall: '{min: 0, max: 4}, rise: '{min: 2, max: 8}};

  integer range_passes = 0;
  integer range_failures = 0;
  integer repeat_passes = 0;
  integer repeat_failures = 0;
  integer value_failures = 0;

  // Exercise ordinary aggregate-parameter member elaboration too. The SVA
  // parser folds its bounds early, so this check prevents a dummy aggregate
  // value from hiding behind otherwise-correct assertion behavior.
  initial begin
    if (PeriCycles.fall.min != 0 || PeriCycles.fall.max != 4 ||
        PeriCycles.rise.min != 2 || PeriCycles.rise.max != 8)
      value_failures += 1;
  end

  member_range: assert property (@(posedge clk)
      req_range |-> ##[PeriCycles.fall.min:PeriCycles.fall.max] ack_range)
    range_passes += 1;
  else
    range_failures += 1;

  member_repeat_and_difference: assert property (@(posedge clk)
      req_repeat ##1 hold_repeat [* PeriCycles.rise.min]
      |=> ##[0:PeriCycles.rise.max-PeriCycles.rise.min] ack_repeat)
    repeat_passes += 1;
  else
    repeat_failures += 1;
endinterface

module sv_assert_unpacked_struct_parameter_delay;
  logic clk = 0;
  logic req_range = 0;
  logic req_repeat = 0;
  logic hold_repeat = 0;
  logic ack_range = 0;
  logic ack_repeat = 0;

  unpacked_struct_parameter_delay_if check_if (.*);

  always #5 clk = ~clk;

  task automatic drive(input logic rr, input logic rp, input logic hold,
                       input logic ar, input logic ap);
    @(negedge clk);
    req_range = rr;
    req_repeat = rp;
    hold_repeat = hold;
    ack_range = ar;
    ack_repeat = ap;
  endtask

  initial begin
    // Launch both checks at c1. The range takes its exact upper endpoint
    // at c5. The two-cycle repetition ends at c3; its nonoverlapped [0:6]
    // consequence takes its exact upper endpoint at c10.
    drive(1, 1, 0, 0, 0); // c1
    drive(0, 0, 1, 0, 0); // c2
    drive(0, 0, 1, 0, 0); // c3
    drive(0, 0, 0, 0, 0); // c4
    drive(0, 0, 0, 1, 0); // c5
    drive(0, 0, 0, 0, 0); // c6
    drive(0, 0, 0, 0, 0); // c7
    drive(0, 0, 0, 0, 0); // c8
    drive(0, 0, 0, 0, 0); // c9
    drive(0, 0, 0, 0, 1); // c10
    drive(0, 0, 0, 0, 0); // c11
    drive(0, 0, 0, 0, 0); // c12 / flush
    @(negedge clk);

    if (check_if.value_failures != 0)
      $display("FAILED -- aggregate localparam member values");
    else if (check_if.range_passes != 1 || check_if.range_failures != 0)
      $display("FAILED -- selected range bounds: %0d/%0d",
               check_if.range_passes, check_if.range_failures);
    else if (check_if.repeat_passes != 1 || check_if.repeat_failures != 0)
      $display("FAILED -- selected repetition/difference bounds: %0d/%0d",
               check_if.repeat_passes, check_if.repeat_failures);
    else
      $display("PASSED");
    $finish;
  end
endmodule
