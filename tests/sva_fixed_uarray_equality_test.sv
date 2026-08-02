module sva_fixed_uarray_equality_test;
  bit clk, rst_n, trig;
  logic [127:0] a [2];
  logic [127:0] b [2];
  wire arrays_equal = (a == b);
  int passes, failures;

  always #5 clk = ~clk;

  assert property (@(posedge clk) disable iff (!rst_n)
                   trig |=> a == $past(b))
    passes++; else failures++;

  initial begin
    rst_n = 0;
    a = '{128'h0, 128'h0};
    b = '{128'h10000000000000000000000000,
           128'h20000000000000000000000000};
    @(negedge clk);
    rst_n = 1;
    trig = 1;
    @(negedge clk);
    trig = 0;
    a = '{128'h10000000000000000000000000,
           128'h20000000000000000000000000};
    b = '{128'h30000000000000000000000000,
           128'h40000000000000000000000000};
    @(negedge clk);
    if (arrays_equal) $fatal(1, "live whole-array equality is wrong");
    repeat (2) @(negedge clk);
    if (passes != 1 || failures != 0)
      $fatal(1, "fixed-array SVA equality counters %0d/%0d",
             passes, failures);
    $display("PASS: fixed unpacked-array equality and per-element $past");
    $finish;
  end
endmodule
