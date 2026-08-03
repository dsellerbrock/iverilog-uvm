package sva_contextual_constants_clock_pkg;
  typedef enum integer {SBoxImplLut, SBoxImplCanright,
                        SBoxImplCanrightMasked,
                        SBoxImplCanrightMaskedNoreuse,
                        SBoxImplDom} sbox_impl_e;
endpackage

module sva_contextual_constants_clock_test;
  import sva_contextual_constants_clock_pkg::*;
  parameter sbox_impl_e SecSBoxImpl = SBoxImplDom;
  bit clk, rst_n, data, trig, param_sig, long_trig, long_done;
  int past_pass, past_fail, param_pass, param_fail, long_pass, long_fail;
  localparam int BaseDepth = 1;
  localparam int PastDepth =
      (SecSBoxImpl == SBoxImplDom) ? BaseDepth + 1 : 1;

  always #5 clk = ~clk;

  property parameterized_clock_p(x, c, r);
    @(posedge c) disable iff (!r) x |-> x;
  endproperty

  assert property (parameterized_clock_p(param_sig, clk, rst_n))
    param_pass++; else param_fail++;

  assert property (@(posedge clk) disable iff (!rst_n)
                   trig |-> $past(data, PastDepth) == 1'b1)
    past_pass++; else past_fail++;

  // A bounded range is not semantically limited to 512 cycles. This also
  // protects the scalable window lowering used by OTBN's 4000-cycle checks.
  assert property (@(posedge clk) disable iff (!rst_n)
                   long_trig |=> ##[1:600] long_done)
    long_pass++; else long_fail++;

  initial begin
    rst_n = 0;
    @(negedge clk);
    rst_n = 1;
    data = 1;
    param_sig = 1;
    @(negedge clk);
    param_sig = 0;
    data = 0;
    long_trig = 1;
    @(negedge clk);
    long_trig = 0;
    data = 1;
    trig = 1;
    @(negedge clk);
    trig = 0;
    long_done = 1;
    @(negedge clk);
    long_done = 0;
    repeat (2) @(negedge clk);

    if (past_pass != 1 || past_fail != 0 ||
        param_pass != 1 || param_fail != 0 ||
        long_pass != 1 || long_fail != 0)
      $fatal(1, "contextual SVA counters p=%0d/%0d c=%0d/%0d l=%0d/%0d",
             past_pass, past_fail, param_pass, param_fail,
             long_pass, long_fail);
    $display("PASS: constant $past depth, declaration clock, and long window");
    $finish;
  end
endmodule
