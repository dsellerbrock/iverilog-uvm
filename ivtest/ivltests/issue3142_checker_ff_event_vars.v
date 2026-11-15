// IEEE 1800-2023 17.5: "Except for the variables used in the event control,
// all other expressions in always_ff procedures are sampled." The reset of
// an asynchronous-reset always_ff in a checker is read with its current
// value, as the standard's own example notes; the data input is sampled.
checker ck(input logic clk, input logic rst, input logic [1:0] d,
           output logic [1:0] q);
  always_ff @(posedge clk or posedge rst)
    if (rst) q <= 2'b00;   // current value of rst
    else q <= d;           // sampled value of d
endchecker

module top;
  logic clk = 0, rst = 0;
  logic [1:0] d = 2'b01, q;
  int errors = 0;
  ck c(clk, rst, d, q);

  task automatic expect_q(input logic [1:0] want);
    if (q !== want) begin
      $display("FAILED: t=%0t q=%b want=%b", $time, q, want);
      errors += 1;
    end
  endtask

  initial begin
    // d changes with the clock edge: the checker sees its sampled (old)
    // value, 01.
    #5 clk = 1; d = 2'b11;
    #1 expect_q(2'b01);
    // The reset rises alone: its current value selects the reset branch.
    #4 rst = 1;
    #1 expect_q(2'b00);
    #4 clk = 0; rst = 0;
    #5 clk = 1;
    #1 expect_q(2'b11);
    if (errors == 0) $display("PASSED");
  end
endmodule
