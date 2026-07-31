// IEEE 1800-2017 10.4 / 10.9: `m[1] <= '{a,b,c}' -- an assignment
// pattern written NON-BLOCKING into an unpacked-array slice.
//
// This is the silent one. The r-value evaluator has no case for an
// array pattern, so it pushed a ZERO of the l-value's width instead and
// the compile SUCCEEDED. A slice l-value carries a word index (the
// slice's flat base), so nothing tripped over the missing one: the zero
// was stored into the slice's first word and the other two words were
// simply dropped. The simulation ran to completion and reported zeros
// where the pattern values belonged.
//
// The blocking spelling of the same line has always been correct, which
// is what makes the divergence a defect rather than a missing feature.
// This test therefore checks both spellings against the same expected
// values, and checks that the neighbouring slice is left alone.
module sv_uarray_nb_pattern_slice;

  logic [7:0] mnb [2][3];
  logic [7:0] mbl [2][3];

  reg clk = 0;
  integer errors = 0;

  always #5 clk = ~clk;

  always_ff @(posedge clk) mnb[1] <= '{8'hA1, 8'hB2, 8'hC3};
  always_ff @(posedge clk) mbl[1]  = '{8'hA1, 8'hB2, 8'hC3};

  task check(input [7:0] got, input [7:0] exp, input [127:0] what);
    begin
      if (got !== exp) begin
        $display("MISMATCH %0s: got %h expected %h", what, got, exp);
        errors = errors + 1;
      end
    end
  endtask

  initial begin
    foreach (mnb[i,j]) mnb[i][j] = 8'h00;
    foreach (mbl[i,j]) mbl[i][j] = 8'h00;

    @(posedge clk);
    @(posedge clk);

    $display("nb  m[1] = %h %h %h", mnb[1][0], mnb[1][1], mnb[1][2]);
    $display("blk m[1] = %h %h %h", mbl[1][0], mbl[1][1], mbl[1][2]);

    check(mnb[1][0], 8'hA1, "nb m[1][0]");
    check(mnb[1][1], 8'hB2, "nb m[1][1]");
    check(mnb[1][2], 8'hC3, "nb m[1][2]");

    // The non-blocking form must land the same values as the blocking one.
    check(mnb[1][0], mbl[1][0], "nb vs blk m[1][0]");
    check(mnb[1][1], mbl[1][1], "nb vs blk m[1][1]");
    check(mnb[1][2], mbl[1][2], "nb vs blk m[1][2]");

    // ...and must not spill into the other slice.
    check(mnb[0][0], 8'h00, "nb m[0][0]");
    check(mnb[0][1], 8'h00, "nb m[0][1]");
    check(mnb[0][2], 8'h00, "nb m[0][2]");

    if (errors == 0)
      $display("PASSED");
    else
      $display("FAILED -- %0d mismatches", errors);
    $finish;
  end

endmodule
