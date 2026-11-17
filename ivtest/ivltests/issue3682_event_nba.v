program observer(input clk, output reg done);
  integer value = 0;
  real r = 0.0;
  initial begin
    done = 0;
    value <= @(posedge clk) 11;
    r <= @(posedge clk) 3.5;
    @(posedge clk);
    if (value !== 0 || r != 0.0)
      $fatal(1, "program update happened before Re-NBA");
    #1;
    if (value !== 11 || r != 3.5)
      $fatal(1, "program Re-NBA update missing");
    done = 1;
    #100;
  end
endprogram

module top;
  reg clk = 0;
  integer a = 0, b = 7, c = 0, idx = 0, count = 2;
  integer ordered = 0;
  reg [7:0] bits = 0;
  reg [7:0] mem [0:1];
  real r = 0.0;
  real rm [0:1];
  real zero = 0.0;
  real zero_var = 0.0, delayed = 0.0;
  integer zero_count = 0;
  wire program_done;
  observer obs(clk, program_done);

  always #5 clk = ~clk;
  always @(posedge clk) c <= 7;

  initial begin
    mem[0] = 0; mem[1] = 0; rm[0] = 0.0; rm[1] = 0.0;
    a <= @(posedge clk) b;
    ordered <= @(posedge clk) 1;
    ordered <= @(posedge clk) 2;
    bits[5:2] <= @(posedge clk) 4'hb;
    mem[idx] <= @(posedge clk) 8'h42;
    r <= @(posedge clk) 1.5;
    rm[idx] <= @(posedge clk) 2.5;
    zero <= repeat(0) @(posedge clk) 4.5;
    zero_var <= repeat(zero_count) @(posedge clk) 5.5;
    delayed <= #2 1.0;
    delayed <= #1 2.0;
    mem[1] <= repeat(count) @(posedge clk) 8'h55;
    b = 9; idx = 1; count = 1;
    #0;
    if (zero != 0.0 || zero_var != 0.0)
      $fatal(1, "zero-repeat real update happened before NBA");
    @(posedge clk);
    if (a !== 0 || c !== 0 || ordered !== 0 || bits !== 0 || mem[0] !== 0 ||
        r != 0.0 || rm[0] != 0.0 || mem[1] !== 0)
      $fatal(1, "event-controlled update happened before NBA");
    #1;
    if (a !== 7 || c !== 7 || ordered !== 2 || bits !== 8'h2c || mem[0] !== 8'h42 ||
        r != 1.5 || rm[0] != 2.5 || zero != 4.5 || zero_var != 5.5 ||
        delayed != 1.0 || mem[1] !== 0)
      $fatal(1, "wrong first-edge values or snapshots");
    @(posedge clk);
    if (mem[1] !== 0) $fatal(1, "repeat update happened before NBA");
    #1;
    if (mem[1] !== 8'h55 || program_done !== 1)
      $fatal(1, "repeat or program update missing");
    $display("PASS");
    $finish(0);
  end
endmodule
