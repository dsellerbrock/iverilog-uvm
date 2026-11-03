checker my_check1 (logic test_sig, event clock);
  default clocking @clock; endclocking
  a1: assert property (test_sig || !test_sig);
endchecker : my_check1

checker my_check2 (logic a, b);
  a1: assert #0 ($onehot0({a, b}));
endchecker : my_check2

checker my_check3 (logic a, b, event clock, output bit failure, undef);
  default clocking @clock; endclocking
  a1: assert property ($onehot0({a, b}))
      failure = 1'b0; else failure = 1'b1;
  a2: assert property ($isunknown({a, b}))
      undef = 1'b1; else undef = 1'b0;
endchecker : my_check3

module sv_checker_event_formal;
  logic clk = 0;
  logic a = 0, b = 0;
  logic failure, undef, sampled;

  always #5 clk = ~clk;

  my_check1 check1(a, posedge clk);
  my_check3 check3(a, b, posedge clk, failure, undef);

  always @(posedge clk)
    sampled <= failure;

  initial begin
    #16;
    if (failure !== 1'b1 || undef !== 1'b0 || sampled !== 1'b0)
      $fatal(1, "checker output did not update in Reactive: %b %b %b",
             failure, undef, sampled);
    a = 0;
    b = 0;
    #10;
    if (failure !== 1'b0 || sampled !== 1'b1)
      $fatal(1, "checker output/Reactive sampling mismatch: %b %b",
             failure, sampled);
    #10;
    if (sampled !== 1'b0)
      $fatal(1, "checker output did not settle: %b", sampled);
    $display("PASS");
    $finish;
  end

  initial begin
    #6;
    a = 1;
    b = 1;
  end
endmodule
