// Equal finite repetition bounds are valid and describe one exact endpoint.
// The 7:9 declaration defaults differ from the 2:2 instance override, so one
// short isolated attempt also proves that both finite-range overrides reach
// the instance-sized implication checker.
module cover_parameter_repeat_range_equal_checker #(
  parameter int LO = 7,
  parameter int HI = 9
) (
  input logic clk,
  input logic start,
  input logic keep,
  input logic result
);
  equal: cover property (@(posedge clk)
    start ##1 keep[*LO:HI] |-> ##1 result);
endmodule

module sv_cover_parameter_repeat_range_equal;
  logic clk = 0;
  logic start = 0;
  logic keep = 1;
  logic result = 0;

  cover_parameter_repeat_range_equal_checker #(
    .LO(2),
    .HI(2)
  ) dut (.*);

  task automatic tick;
    #1 clk = 1;
    #1 clk = 0;
  endtask

  initial begin
    // t1 launches; keep at t2/t3 produces the sole [*2:2] endpoint;
    // the fixed ##1 consequence matches at t4.
    start = 1;
    tick();
    start = 0;
    tick();
    tick();
    result = 1;
    tick();

    if (dut._ivl_sva0_cnt0 !== 1) begin
      $display("FAILED: [*2:2] implication count was %0d, expected 1",
               dut._ivl_sva0_cnt0);
      $finish_and_return(1);
    end
    $display("PASSED");
    $finish;
  end
endmodule
