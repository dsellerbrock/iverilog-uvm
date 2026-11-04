module issue715_sva_local_decl_init;
  logic clk = 0;
  logic start = 1;
  int payload = 0;
  int result1 = 0;
  int result2 = 0;
  always #5 clk = ~clk;

  // The assertion samples payload before this blocking Active-region update.
  always @(posedge clk) begin
    payload = payload + 1;
    result1 <= payload;
    result2 <= payload + 1;
  end

  property overlapping_attempts;
    int sampled = payload, expected = sampled + 1;
    @(posedge clk) start ##1 (result1 == expected);
  endproperty
  assert property (overlapping_attempts)
    else $fatal(1, "declaration initialization or per-attempt storage failed");

  property formal_argument(int base);
    int expected = base + 2;
    @(posedge clk) start ##1 (result2 == expected);
  endproperty
  assert property (formal_argument(payload))
    else $fatal(1, "formal argument initialization ordering failed");

  sequence sequence_local;
    int expected = payload + 1;
    start ##1 (result1 == expected);
  endsequence
  assert property (@(posedge clk) sequence_local)
    else $fatal(1, "sequence local initialization failed");

  initial begin
    #40;
    $display("issue715 assertion variable initialization PASS");
    $finish;
  end
endmodule
