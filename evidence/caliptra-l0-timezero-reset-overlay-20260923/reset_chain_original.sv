module flop(input logic clk, rst_l, output logic dout);
  always_ff @(posedge clk or negedge rst_l)
    if (rst_l == 0) dout <= 0;
    else dout <= 1;
endmodule
module top;
  logic clk, pwrgood, tb_rst_l, scan_mode, uc_rst_nq, rst_l, done, valid;
  initial begin
    pwrgood = 0; tb_rst_l = 0; scan_mode = 0; clk = 0;
    #5 clk = 1;
    #5 $finish;
  end
  always_ff @(posedge clk or negedge pwrgood)
    if (!pwrgood) uc_rst_nq <= 0;
    else uc_rst_nq <= 1;
  assign rst_l = scan_mode ? tb_rst_l : uc_rst_nq;
  flop a(clk, rst_l, done), b(clk, rst_l, valid);
  assert_fifo_done_and_novalid: assert #0 (~done | valid);
  initial #0 $display("AT0 reset=%b done=%b valid=%b expr=%b", rst_l, done, valid, ~done | valid);
  initial #1 $display("AT1 reset=%b done=%b valid=%b expr=%b", rst_l, done, valid, ~done | valid);
endmodule
