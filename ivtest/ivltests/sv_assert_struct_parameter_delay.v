// IEEE 1800-2017 16.9.2: sequence delay and repetition bounds may be
// constant expressions.  A selected member of a localparam struct is a
// constant expression too.  OpenTitan's rstmgr assertions use this exact
// nested named-assignment-pattern shape.
interface struct_parameter_delay_if (
  input logic clk,
  input logic req_range,
  input logic req_repeat,
  input logic hold_repeat,
  input logic ack_range,
  input logic ack_repeat
);
  typedef struct packed {
    int min;
    int max;
  } bounds_t;

  typedef struct packed {
    bounds_t fall;
    bounds_t rise;
  } edge_bounds_t;

  localparam edge_bounds_t Cycles =
      '{fall: '{min: 1, max: 2}, rise: '{min: 2, max: 4}};

  integer range_passes = 0;
  integer range_failures = 0;
  integer repeat_passes = 0;
  integer repeat_failures = 0;

  member_range: assert property (@(posedge clk)
      req_range |-> ##[Cycles.fall.min:Cycles.fall.max] ack_range)
    range_passes += 1;
  else
    range_failures += 1;

  member_repeat_and_difference: assert property (@(posedge clk)
      req_repeat ##1 hold_repeat [* Cycles.rise.min]
      |=> ##[0:Cycles.rise.max-Cycles.rise.min] ack_repeat)
    repeat_passes += 1;
  else
    repeat_failures += 1;
endinterface

module sv_assert_struct_parameter_delay;
  logic clk = 0;
  logic req_range = 0;
  logic req_repeat = 0;
  logic hold_repeat = 0;
  logic ack_range = 0;
  logic ack_repeat = 0;

  struct_parameter_delay_if check_if (.*);

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
    // Launch both checks at c1.  The ranged check matches at its two-cycle
    // endpoint (c3).  The repetition consumes hold at c2/c3; its
    // nonoverlapped [0:2] consequence then matches at c5.
    drive(1, 1, 0, 0, 0); // c1
    drive(0, 0, 1, 0, 0); // c2
    drive(0, 0, 1, 1, 0); // c3
    drive(0, 0, 0, 0, 0); // c4
    drive(0, 0, 0, 0, 1); // c5
    drive(0, 0, 0, 0, 0); // c6
    drive(0, 0, 0, 0, 0); // c7 / flush
    @(negedge clk);

    if (check_if.range_passes != 1 || check_if.range_failures != 0)
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
