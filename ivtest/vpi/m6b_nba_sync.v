// M6B-2: cbNBASynch (IEEE 1800-2017 clause 38) -- the post-NBA callback
// point. Before this existed, cbNBASynch was not even defined in
// vpi_user.h, so a VPI application that registered it failed to compile.
//
// `q' is updated by a nonblocking assignment at the t=5 edge, so its
// value at each callback says which side of the NBA region the callback
// ran on. All four simulation-time callbacks must see q=1.
//
// The callbacks are registered in reverse region order, so cbNBASynch --
// registered last, reported first -- proves the new post-NBA queue is
// drained by the scheduler ahead of the existing sync points rather than
// by registration order. cbReadWriteSynch and cbAtEndOfSimTime share the
// one Pre-Postponed queue, so between those two the order IS registration
// order; that is what the trailing two lines record.
module top;
  reg clk = 0;
  reg [7:0] q = 8'd0;

  always #5 clk = ~clk;
  always @(posedge clk) q <= q + 1;

  initial begin
    $m6b_nba_sync_setup(q);
    #12 $finish(0);
  end
endmodule
