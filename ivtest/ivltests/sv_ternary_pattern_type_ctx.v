// IEEE 1800-2017 11.4.11 makes a conditional an assignment-like context
// for BOTH of its result expressions, so the target type has to reach
// each arm -- an assignment pattern has no meaning without the type it
// is filling in.
//
// Two things were missing. elaborate_rval_expr only recognized a DIRECT
// PEAssignPattern as needing typed elaboration, so a pattern nested in a
// conditional went down the width path; and PETernary had no
// type-context elaborate_expr at all, so PExpr's default forwarded to
// the WIDTH form with a width of 1. A chain of conditionals whose arms
// are patterns -- hmac_core.sv's sha_rdata_o -- failed with "Unable to
// elaborate r-value".
//
// Values are checked per arm, so a fix that merely compiled while
// placing members in the wrong slice still fails here. The nesting is
// deliberately several levels deep, matching the source shape.
module sv_ternary_pattern_type_ctx;

  typedef struct packed { logic [31:0] data; logic [3:0] mask; } sd_t;

  logic       sel;
  logic [1:0] k;
  sd_t        fifo;
  sd_t        o_net;    // through a continuous assign
  sd_t        o_proc;   // through a procedural assign
  int errors = 0;

  assign fifo = '{data: 32'hFEED_FACE, mask: 4'h3};

  assign o_net =
      (!sel)        ? fifo                                     :
      (k == 2'd1)   ? '{data: 32'hAAAA_BBBB, mask: '1}         :
      (k == 2'd2)   ? '{data: 32'hCCCC_DDDD, mask: 4'h5}       :
                      '{data: 32'h1234_5678, mask: 4'h0};

  always_comb
    o_proc =
      (!sel)        ? fifo                                     :
      (k == 2'd1)   ? '{data: 32'hAAAA_BBBB, mask: '1}         :
      (k == 2'd2)   ? '{data: 32'hCCCC_DDDD, mask: 4'h5}       :
                      '{data: 32'h1234_5678, mask: 4'h0};

  task ck(input string t, input [35:0] got, input [35:0] exp);
    if (got !== exp) begin
      $display("FAIL %0s: got %h expected %h", t, got, exp);
      errors = errors + 1;
    end
  endtask

  initial begin
    sel = 1'b0; k = 2'd0; #1;
    ck("net_passthru",  o_net,  {32'hFEED_FACE, 4'h3});
    ck("proc_passthru", o_proc, {32'hFEED_FACE, 4'h3});

    sel = 1'b1; k = 2'd1; #1;
    ck("net_arm1",  o_net,  {32'hAAAA_BBBB, 4'hF});
    ck("proc_arm1", o_proc, {32'hAAAA_BBBB, 4'hF});

    sel = 1'b1; k = 2'd2; #1;
    ck("net_arm2",  o_net,  {32'hCCCC_DDDD, 4'h5});
    ck("proc_arm2", o_proc, {32'hCCCC_DDDD, 4'h5});

    sel = 1'b1; k = 2'd3; #1;
    ck("net_arm3",  o_net,  {32'h1234_5678, 4'h0});
    ck("proc_arm3", o_proc, {32'h1234_5678, 4'h0});

    // the two spellings must agree at every point
    ck("agree", o_net, o_proc);

    if (errors == 0) $display("PASSED");
    else $display("FAILED with %0d errors", errors);
  end

endmodule
