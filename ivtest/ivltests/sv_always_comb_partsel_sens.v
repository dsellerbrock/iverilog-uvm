// An always_comb must stay sensitive to what it READS, even when it
// also WRITES another part of the same variable.
//
// NetAssign_::nex_output reported the ENTIRE signal for any bit/part
// select l-value, and NetBlock::nex_input subtracts the block's outputs
// from its inputs to build the sensitivity list. So
//
//     always_comb begin
//       tmp   = st[0] ^ 8'h0F;   // reads st (widened to all bits)
//       st[1] = tmp + 8'd1;      // claimed ALL of st as an output
//     end
//
// came out with an EMPTY sensitivity set: the process ran once at time
// 0 and then simulated a stale value for the rest of the run. The
// compiler warned ("always_comb process has no sensitivities"), so it
// was loud, but the simulation was wrong.
//
// Three ingredients were needed together, and each is exercised below:
// a constant select whose sensitivity widens to the whole variable, a
// write to another element of that SAME variable, and an intermediate
// written and read inside the block. Dropping any one was already
// correct, so the surviving cases are here as controls -- they pin that
// the fix did not change them.
module sv_always_comb_partsel_sens;

  logic [3:0][7:0] st;
  logic      [7:0] seed, tmp, out_scalar, out_plain;
  logic     [31:0] v;
  int errors = 0;

  always_comb st[0] = seed;

  // the failing shape: read st[0], write tmp, write st[1]
  always_comb begin : p_stale
    tmp   = st[0] ^ 8'h0F;
    st[1] = tmp + 8'd1;
  end

  // control: no intermediate
  always_comb st[2] = (st[0] ^ 8'h0F) + 8'd1;

  // control: intermediate, but the target is outside st
  logic [7:0] tmp2;
  always_comb begin : p_outside
    tmp2       = st[0] ^ 8'h0F;
    out_plain  = tmp2 + 8'd1;
  end

  // control: intermediate, plain scalar read
  logic [7:0] tmp3;
  always_comb begin : p_scalar
    tmp3       = seed ^ 8'h0F;
    out_scalar = tmp3 + 8'd1;
  end

  // disjoint part selects of one plain vector, same shape
  logic [7:0] tmp4;
  always_comb begin : p_part
    tmp4    = v[7:0] ^ 8'h0F;
    v[15:8] = tmp4 + 8'd1;
  end
  always_comb v[7:0] = seed;

  function [7:0] round(input [7:0] x);
    round = (x ^ 8'h0F) + 8'd1;
  endfunction

  task ck(input string t, input [7:0] got, input [7:0] exp);
    if (got !== exp) begin
      $display("FAIL %0s: got %h expected %h", t, got, exp);
      errors = errors + 1;
    end
  endtask

  initial begin
    seed = 8'hA5; #1;
    ck("stale_a",   st[1],      round(8'hA5));
    ck("ctrl_noint",st[2],      round(8'hA5));
    ck("ctrl_out",  out_plain,  round(8'hA5));
    ck("ctrl_scal", out_scalar, round(8'hA5));
    ck("part_lo",   v[7:0],     8'hA5);
    ck("part_hi",   v[15:8],    round(8'hA5));

    // the value must FOLLOW seed -- this is what used to go stale
    seed = 8'h3C; #1;
    ck("stale_b",   st[1],      round(8'h3C));
    ck("ctrl_nointb",st[2],     round(8'h3C));
    ck("ctrl_outb", out_plain,  round(8'h3C));
    ck("ctrl_scalb",out_scalar, round(8'h3C));
    ck("part_lob",  v[7:0],     8'h3C);
    ck("part_hib",  v[15:8],    round(8'h3C));

    seed = 8'h00; #1;
    ck("stale_c",   st[1],      round(8'h00));
    ck("part_hic",  v[15:8],    round(8'h00));

    if (errors == 0) $display("PASSED");
    else $display("FAILED with %0d errors", errors);
  end

endmodule
