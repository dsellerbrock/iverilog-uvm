// Whole unpacked-array copy by NON-BLOCKING assignment (IEEE
// 1800-2017 7.6). 10.4 draws no blocking/non-blocking distinction over
// which assignments are legal, so `q <= d' is as legal as `p = d'.
//
// Only the blocking form had a whole-array branch; the non-blocking
// spelling fell through to the typed r-value path, which has no
// whole-array representation for a word-array signal, and failed with
//   error: the type of the variable 'd' doesn't match the context type.
// The compiler accepting the blocking spelling proved it had the
// representation all along.
//
// This test is discriminating in TWO ways. Pre-fix it does not compile
// at all. And it checks that the copy kept NON-BLOCKING scheduling:
// the source is written in the same time step, so a copy that had been
// lowered to blocking word-assignments would capture the NEW value.
module sv_nb_uarray_copy;
  logic clk = 0;
  logic [7:0] d [2];
  logic [7:0] q [2];
  logic [7:0] p [2];

  initial begin d[0] = 8'h11; d[1] = 8'h22; end

  always_comb p = d;                 // blocking form (worked before)

  always_ff @(posedge clk) begin
    q <= d;                          // non-blocking whole-array copy
    d[0] <= 8'hAA;                   // same-step write to the source
  end

  initial begin
    #5 clk = 1;
    #5;
    if (q[0] === 8'h11 && q[1] === 8'h22 &&   // captured the OLD d
        d[0] === 8'hAA &&                      // source did update
        p[0] === 8'hAA && p[1] === 8'h22)      // blocking form tracks
      $display("PASSED");
    else
      $display("FAILED q=%h,%h d=%h,%h p=%h,%h",
               q[0], q[1], d[0], d[1], p[0], p[1]);
  end
endmodule
