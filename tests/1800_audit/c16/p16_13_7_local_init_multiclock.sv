`timescale 1ns/1ps
module p16_13_7_local_init_multiclock;
  logic clk = 0, clk1 = 0, clk2 = 0;
  logic f = 0, e = 0, a = 0, b = 0, c = 0, d = 0;
  int failures = 0;

  property p;
    logic v = e;
    (@(posedge clk1) (a == v)[*1:$] |-> b)
    and
    (@(posedge clk2) c[*1:$] |-> d == v);
  endproperty

  a1: assert property (@(posedge clk) f |=> p)
    else begin
      $display("FAIL: §16.13.7 local variable initialization");
      failures++;
    end

  initial begin
    #1 f = 1;
    #1 clk = 1;
    #1 clk = 0; f = 0;
    #1 clk = 1;
    #1 clk = 0;
    #1 e = 1; a = 1; b = 1;
    #1 clk1 = 1;
    #1 clk1 = 0; e = 0; c = 1; d = 0;
    #1 clk2 = 1;
    #1 clk2 = 0;
    #1;
    if (failures != 0) $fatal(1, "local variable initialization failures=%0d", failures);
    $display("PASS: §16.13.7 separate semantic-leading-clock initializers");
    $finish;
  end
endmodule
