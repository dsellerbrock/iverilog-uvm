`timescale 1ns/1ps
module sum_loop_shift(input logic clk, rst_n, zeroize,
                 input logic [1:0] sum_in [45:0], last_sum,
                 output logic [1:0] tap [45:0]);
  logic [45:0][45:0][1:0] sum_reg;
  for (genvar i = 0; i < 46; i++) begin : g
    assign tap[i] = sum_reg[i][45];
    always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n) sum_reg[i] <= '0;
      else if (zeroize) sum_reg[i] <= '0;
      else begin
        for (int j = i; j < 46; j++) begin
          if (j == i && i == 45) sum_reg[i][j] <= last_sum;
          else if (j == i) sum_reg[i][j] <= sum_in[i];
          else sum_reg[i][j] <= sum_reg[i][j-1];
        end
      end
    end
  end
endmodule
`timescale 1ns/1ps
module sum_vector_shift(input logic clk, rst_n, zeroize,
                 input logic [1:0] sum_in [45:0], last_sum,
                 output logic [1:0] tap [45:0]);
  logic [45:0][45:0][1:0] sum_reg;
  for (genvar i = 0; i < 46; i++) begin : g
    assign tap[i] = sum_reg[i][45];
    always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n) sum_reg[i] <= '0;
      else if (zeroize) sum_reg[i] <= '0;
      else begin
        if (i == 45) sum_reg[i][45] <= last_sum;
        else sum_reg[i][45:i] <= {sum_reg[i][44:i], sum_in[i]};
      end
    end
  end
endmodule
module sum_eq_tb;
  logic clk = 0, rst_n = 0, zeroize = 0;
  logic [1:0] sum_in [45:0], last_sum, lt [45:0], vt [45:0];
  sum_loop_shift lhs(clk, rst_n, zeroize, sum_in, last_sum, lt);
  sum_vector_shift rhs(clk, rst_n, zeroize, sum_in, last_sum, vt);
  always #5 clk = ~clk;
  initial begin
    for (int k = 0; k < 46; k++) sum_in[k] = 'x;
    last_sum = 'x;
    for (int n = 0; n < 120; n++) begin
      @(negedge clk);
      rst_n = (n % 41 != 0);
      zeroize = (n % 23 == 0);
      last_sum = n;
      if (n % 7 == 0) last_sum[0] = 1'bx;
      for (int k = 0; k < 46; k++) begin
        sum_in[k] = (n * 17 + k * 23) >> (k % 4);
        if ((n + k) % 11 == 0) sum_in[k][1] = 1'bx;
        if ((n + k) % 13 == 0) sum_in[k][0] = 1'bz;
      end
      @(posedge clk); #1;
      if (lhs.sum_reg !== rhs.sum_reg)
        $fatal(1, "sum state mismatch at cycle %0d", n);
    end
    $display("sum equivalence PASS: 120 cycles, full four-state register");
    $finish;
  end
endmodule
