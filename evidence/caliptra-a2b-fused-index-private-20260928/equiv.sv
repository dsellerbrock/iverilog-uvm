`timescale 1ns/1ps
module loop_shift(input logic clk, rst_n, zeroize,
                 input logic [1:0] x [45:0],
                 input logic [45:0] rnd0, rnd1,
                 output logic [1:0] tap_x [45:0], tap_y [45:0]);
  logic [45:0][45:0][1:0] x_reg, y_reg;
  for (genvar i = 0; i < 46; i++) begin : g
    assign tap_x[i] = x_reg[i][i];
    assign tap_y[i] = y_reg[i][i];
    always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin x_reg[i] <= '0; y_reg[i] <= '0; end
      else if (zeroize) begin x_reg[i] <= '0; y_reg[i] <= '0; end
      else begin
        for (int j = 0; j < 46; j++) begin
          if (j == 0) begin
            x_reg[i][j] <= {rnd0[i], x[i][0] ^ rnd0[i]};
            y_reg[i][j] <= {rnd1[i], x[i][1] ^ rnd1[i]};
          end else begin
            x_reg[i][j] <= x_reg[i][j-1];
            y_reg[i][j] <= y_reg[i][j-1];
          end
        end
      end
    end
  end
endmodule

`timescale 1ns/1ps
module vector_shift(input logic clk, rst_n, zeroize,
                 input logic [1:0] x [45:0],
                 input logic [45:0] rnd0, rnd1,
                 output logic [1:0] tap_x [45:0], tap_y [45:0]);
  logic [45:0][45:0][1:0] x_reg, y_reg;
  for (genvar i = 0; i < 46; i++) begin : g
    assign tap_x[i] = x_reg[i][i];
    assign tap_y[i] = y_reg[i][i];
    always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin x_reg[i] <= '0; y_reg[i] <= '0; end
      else if (zeroize) begin x_reg[i] <= '0; y_reg[i] <= '0; end
      else begin
        x_reg[i] <= {x_reg[i][44:0], {rnd0[i], x[i][0] ^ rnd0[i]}};
        y_reg[i] <= {y_reg[i][44:0], {rnd1[i], x[i][1] ^ rnd1[i]}};
      end
    end
  end
endmodule

module eq_tb;
  logic clk = 0, rst_n = 0, zeroize = 0;
  logic [1:0] x [45:0], lx [45:0], ly [45:0], vx [45:0], vy [45:0];
  logic [45:0] rnd0, rnd1;
  loop_shift lhs(clk, rst_n, zeroize, x, rnd0, rnd1, lx, ly);
  vector_shift rhs(clk, rst_n, zeroize, x, rnd0, rnd1, vx, vy);
  always #5 clk = ~clk;
  initial begin
    for (int k = 0; k < 46; k++) x[k] = 'x;
    rnd0 = 'x; rnd1 = 'x;
    for (int n = 0; n < 120; n++) begin
      @(negedge clk);
      rst_n = (n % 41 != 0);
      zeroize = (n % 23 == 0);
      rnd0 = n * 32'h9e3779b9;
      rnd1 = n * 32'h7f4a7c15;
      if (n % 7 == 0) rnd0[n % 46] = 1'bx;
      for (int k = 0; k < 46; k++) begin
        x[k] = (n * 17 + k * 23) >> (k % 4);
        if ((n + k) % 11 == 0) x[k][1] = 1'bx;
        if ((n + k) % 13 == 0) x[k][0] = 1'bz;
      end
      @(posedge clk); #1;
      if (lhs.x_reg !== rhs.x_reg || lhs.y_reg !== rhs.y_reg)
        $fatal(1, "state mismatch at cycle %0d", n);
    end
    $display("equivalence PASS: 120 cycles, full four-state x/y registers");
    $finish;
  end
endmodule
