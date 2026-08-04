// A direct parameter-valued repetition consumes keep on the assertion's
// current sampled tick: keep[*1] |-> result checks both operands together,
// while keep[*3] requires the current and two preceding keep samples.
// The declaration default must not leak into either overridden instance.
module direct_repeat_checker #(
  parameter int Count = 8
) (
  input logic clk,
  input logic keep,
  input logic result
);
  integer pass_count = 0;
  integer fail_count = 0;

  exact: assert property (@(posedge clk)
    keep [*Count] |-> result)
      pass_count += 1;
    else
      fail_count += 1;
endmodule

module sv_assert_repeat_parameter_direct;
  logic clk = 0;
  logic keep = 0;
  logic result = 0;

  always #1 clk = ~clk;

  direct_repeat_checker #(.Count(1)) one (.*);
  direct_repeat_checker #(.Count(3)) three (.*);

  task automatic drive(input logic k, input logic r);
    @(negedge clk);
    keep = k;
    result = r;
  endtask

  initial begin
    // Sampled ticks: 11, 10, 11 creates one passing length-3 match;
    // the zero breaks all pending length-3 attempts; 10, 11, 10 then
    // creates one failing length-3 match. Count=1 must verdict on each
    // keep tick using result from that SAME tick.
    drive(1, 1);
    drive(1, 0);
    drive(1, 1);
    drive(0, 0);
    drive(1, 0);
    drive(1, 1);
    drive(1, 0);
    drive(0, 0);
    @(negedge clk);

    if (one.pass_count != 3 || one.fail_count != 3) begin
      $display("FAILED: [*1] did not verdict on the current sampled tick (%0d/%0d)",
               one.pass_count, one.fail_count);
      $finish_and_return(1);
    end
    if (three.pass_count != 1 || three.fail_count != 1) begin
      $display("FAILED: [*3] consecutive history/endpoint was wrong (%0d/%0d)",
               three.pass_count, three.fail_count);
      $finish_and_return(1);
    end
    $display("PASSED");
    $finish;
  end
endmodule
