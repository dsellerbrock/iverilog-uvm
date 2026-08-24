// A direct packed-struct member in a concurrent assertion must be sampled in
// the Preponed region (IEEE 1800-2017 16.5.1). Each update below is a blocking
// assignment in the same time slot as its clock edge, so the assertion must
// see the value from before that update.
module sv_assert_packed_member_preponed_sample;
  typedef struct packed {
    logic [7:0] data;
    logic       valid;
  } rsp_t;

  logic rise_clk = 1'b0;
  logic x_clk = 1'b0;
  rsp_t rise_rsp;
  rsp_t x_rsp;
  logic rise_scalar;
  logic x_scalar;

  int member_0_to_1_failures = 0;
  int scalar_0_to_1_failures = 0;
  int member_1_to_x_failures = 0;
  int scalar_1_to_x_failures = 0;

  // At the rise_clk edge, the sampled value is 0 even though the live value
  // has just become 1.
  member_0_to_1: assert property
      (@(posedge rise_clk) rise_rsp.valid == 1'b0)
    else member_0_to_1_failures++;
  scalar_0_to_1: assert property
      (@(posedge rise_clk) rise_scalar == 1'b0)
    else scalar_0_to_1_failures++;

  // At the x_clk edge, the sampled value is the known 1 even though the live
  // value has just become X. This is the shape used by OpenTitan's
  // dKnown_AKnownEnable check.
  member_1_to_x: assert property
      (@(posedge x_clk) !$isunknown(x_rsp.valid))
    else member_1_to_x_failures++;
  scalar_1_to_x: assert property
      (@(posedge x_clk) !$isunknown(x_scalar))
    else scalar_1_to_x_failures++;

  initial begin
    rise_rsp = '0;
    rise_scalar = 1'b0;
    x_rsp = '0;
    x_rsp.valid = 1'b1;
    x_scalar = 1'b1;

    #5;
    rise_rsp.valid = 1'b1;
    rise_scalar = 1'b1;
    rise_clk = 1'b1;

    #1 rise_clk = 1'b0;
    #4;
    x_rsp.valid = 1'bx;
    x_scalar = 1'bx;
    x_clk = 1'b1;

    #1;
    $display("COUNTS member_0_to_1=%0d scalar_0_to_1=%0d member_1_to_x=%0d scalar_1_to_x=%0d",
             member_0_to_1_failures, scalar_0_to_1_failures,
             member_1_to_x_failures, scalar_1_to_x_failures);
    if (member_0_to_1_failures == 0 &&
        scalar_0_to_1_failures == 0 &&
        member_1_to_x_failures == 0 &&
        scalar_1_to_x_failures == 0)
      $display("PASSED");
    else
      $display("FAILED -- packed member sampled live instead of Preponed");
    $finish;
  end
endmodule
