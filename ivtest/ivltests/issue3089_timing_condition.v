`timescale 1ns/1ns
module issue3089_dut(input d, clk, input [1:0] en, output reg n = 0);
  specify
    $setup(d, posedge clk &&& en, 5, n);
  endspecify
endmodule

module issue3089_expr_dut(input d, clk, input [1:0] en, output reg n = 0);
  specify
    $setup(d, posedge clk &&& (en >> 1), 5, n);
  endspecify
endmodule

module issue3089_timing_condition;
  reg d = 0, clk = 0;
  reg [1:0] en = 2'b10;
  reg d2 = 0, clk2 = 0;
  reg [1:0] en2 = 2'b10;
  wire n, n2;
  issue3089_dut dut(d, clk, en, n);
  issue3089_expr_dut expr_dut(d2, clk2, en2, n2);

  task check(input [1:0] value, input expected);
    begin
      en = value;
      #10 d = ~d;
      #1 clk = 1;
      #1 if (n !== expected) $fatal(1, "en=%b notifier=%b expected=%b", en, n, expected);
      clk = 0;
    end
  endtask

  initial begin
    check(2'b10, 0);
    check(2'b11, 1);
    check(2'bx0, 1);
    check(2'b01, 0);
    check(2'b1x, 0);
    #10 d2 = 1;
    #1 clk2 = 1;
    #1 if (n2 !== 1) $fatal(1, "shifted condition should enable check");
    clk2 = 0;
    en2 = 2'b01;
    #10 d2 = 0;
    #1 clk2 = 1;
    #1 if (n2 !== 1) $fatal(1, "shifted condition should disable check");
    $display("PASS");
    $finish;
  end
endmodule
