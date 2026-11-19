module process_variants(input logic clk);
  logic c, q, r, l;

  initial begin end
  initial #2;
  initial begin : framed
    automatic int n = 1;
    #3;
    if (n != 1) $fatal(1);
  end
  always_comb begin c = clk; end
  always_ff @(posedge clk) q <= c;
  always_ff begin @(posedge clk) r <= c; end
  always_latch if (clk) l = c;
  final begin end
endmodule

module top;
  logic clk = 0;
  process_variants variants(clk);

  always #5 clk = ~clk;
  initial begin
    #1;
    $inspect_processes;
    #5;
    $inspect_processes;
    $finish(0);
  end
endmodule
