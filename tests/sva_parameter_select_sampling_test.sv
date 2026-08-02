module sva_parameter_select_sampling_test;
  typedef struct packed {
    logic enabled;
    logic [2:0] tag;
  } info_t;

  parameter info_t Info = '{enabled: 1'b1, tag: 3'h5};
  parameter logic [2:0] StateEncodings [2] = '{3'h3, 3'h6};

  bit clk;
  logic idx;
  logic [2:0] state;
  int passes, failures;

  assert property (@(posedge clk)
                   Info.enabled && Info.tag == 3'h5 &&
                   state == StateEncodings[idx])
    passes++; else failures++;

  initial begin
    clk = 0;
    idx = 0;
    state = StateEncodings[0];

    // Change the lookup index in Active immediately after causing the edge.
    // The assertion must retain idx's Preponed value and must not try to
    // sample the constant unpacked parameter array itself.
    #5 clk = 1;
    idx = 1;
    #1;

    if (passes != 1 || failures != 0)
      $fatal(1, "parameter select sampling failed: %0d/%0d",
             passes, failures);
    $display("PASS: constant parameter bases retain sampled live selects");
    $finish;
  end
endmodule
