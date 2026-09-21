module nested_invalid_x_row_reset_dut(
  input clk, input rst_n, input en, input [7:0] d,
  output [7:0] q00, q01, q10, q11
);
  reg [7:0] a[2][2];
  integer outer, row;
  localparam logic [1:0] X_ROW = 2'bx;

  always @(posedge clk or negedge rst_n)
    if (!rst_n) begin : reset_block
      // The nested loop's only row is out of range. It must be a no-write.
      for (outer = 0; outer < 1; outer = outer + 1) begin : outer_block
        for (row = 2; row < 3; row = row + 1)
          a[row] <= '{default:0};
      end
      // An X selector is also a no-write for a fixed unpacked array.
      a[X_ROW] <= '{default:0};
    end else if (en) begin
      a[0][0] <= d;       a[0][1] <= d + 8'h01;
      a[1][0] <= a[0][0]; a[1][1] <= a[0][1];
    end

  assign q00 = a[0][0]; assign q01 = a[0][1];
  assign q10 = a[1][0]; assign q11 = a[1][1];
endmodule

module nested_invalid_x_row_reset_tb;
  reg clk = 0, rst_n = 1, en = 0;
  reg [7:0] d = 0;
  wire [7:0] q00, q01, q10, q11;
  nested_invalid_x_row_reset_dut dut(clk, rst_n, en, d, q00, q01, q10, q11);
  always #5 clk = ~clk;

  initial begin
    // Establish distinct values in every word before either no-write reset.
    en = 1; d = 8'h41;
    @(posedge clk); #1;
    d = 8'h73;
    @(posedge clk); #1;
    if (q00 !== 8'h73 || q01 !== 8'h74 || q10 !== 8'h41 || q11 !== 8'h42)
      $fatal(1, "setup rows");

    // t=17 assertion and t=18 deassertion are both away from posedge t=25.
    #1 rst_n = 0; #1;
    if (q00 !== 8'h73 || q01 !== 8'h74 || q10 !== 8'h41 || q11 !== 8'h42)
      $fatal(1, "invalid/X reset selector wrote a row");
    #1 rst_n = 1;
    en = 0;
    @(posedge clk); #1;
    if (q00 !== 8'h73 || q01 !== 8'h74 || q10 !== 8'h41 || q11 !== 8'h42)
      $fatal(1, "post-reset hold changed a row");
    $display("PASSED");
    $finish(0);
  end
endmodule
