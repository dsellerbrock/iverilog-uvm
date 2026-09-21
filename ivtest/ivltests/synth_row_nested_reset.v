module row_async_reset_dut(
  input clk, input rst_n, input en, input [7:0] d,
  output [7:0] q00, q01, q10, q11
);
  reg [7:0] a[2][2];
  integer i, outer;
  always @(posedge clk or negedge rst_n)
    if (!rst_n)
      for (outer = 0; outer < 2; outer = outer + 1) begin : outer_reset
        for (i = 0; i < 2; i = i + 1) begin : inner_reset
          a[i] <= '{default:0};
        end
      end
    else if (en) begin
      a[0][0] <= d;       a[0][1] <= d + 8'h01;
      a[1][0] <= a[0][0]; a[1][1] <= a[0][1];
    end
  assign q00 = a[0][0]; assign q01 = a[0][1];
  assign q10 = a[1][0]; assign q11 = a[1][1];
endmodule

module row_async_reset_tb;
  reg clk = 0, rst_n = 1, en = 0;
  reg [7:0] d = 0;
  wire [7:0] q00, q01, q10, q11;
  row_async_reset_dut dut(clk, rst_n, en, d, q00, q01, q10, q11);
  always #5 clk = ~clk;

  initial begin
    #2 rst_n = 0; #1;
    if (q00 !== 0 || q01 !== 0 || q10 !== 0 || q11 !== 0) $fatal(1, "reset rows");
    #1 rst_n = 1;                 // t=4, one time unit before posedge t=5
    en = 1; d = 8'h41;
    @(posedge clk); #1;
    if (q00 !== 8'h41 || q01 !== 8'h42 || q10 !== 0 || q11 !== 0) $fatal(1, "first shift");
    d = 8'h73;
    @(posedge clk); #1;
    if (q00 !== 8'h73 || q01 !== 8'h74 || q10 !== 8'h41 || q11 !== 8'h42) $fatal(1, "second shift");
    en = 0; d = 8'h99;
    @(posedge clk); #1;
    if (q00 !== 8'h73 || q01 !== 8'h74 || q10 !== 8'h41 || q11 !== 8'h42) $fatal(1, "disabled hold");
    $display("PASSED");
    $finish(0);
  end
endmodule
