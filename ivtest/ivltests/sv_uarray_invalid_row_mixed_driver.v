// High-side constant OOB and X selections do not alias either valid row.
module tb;
  logic [7:0] driven [1:0][0:1];
  logic [7:0] low [0:1];
  logic [7:0] high [0:1];
  logic [7:0] ignored [0:1];
  assign driven[0] = low;
  assign driven[1] = high;
  initial begin
    low[0] = 8'h10; low[1] = 8'h11;
    high[0] = 8'h12; high[1] = 8'h13;
    ignored[0] = 8'h20; ignored[1] = 8'h21;
    driven[2] = ignored;
    driven['x] = ignored;
    driven[-1] = ignored;
    driven[80'h1_0000_0000_0000_0000] = ignored;
    #1;
    if (driven[0][0] !== 8'h10 || driven[0][1] !== 8'h11
        || driven[1][0] !== 8'h12 || driven[1][1] !== 8'h13)
      $fatal(1, "invalid row selection aliased a valid row");
    $display("PASSED");
    $finish(0);
  end
endmodule
