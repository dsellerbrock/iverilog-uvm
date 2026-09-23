// Synthetic Active-region probe distilled from Adams Bridge v2.0.3
// rej_bounded_tb.sv. REVERSE changes the relevant initial-process declaration
// order. FIXED moves the threshold decision into the scoreboard after its
// blocking increment and uses a separate zeroize pulse deassertion process.
module top;
`ifdef REVERSE
  localparam bit REVERSE_ORDER = 1;
`else
  localparam bit REVERSE_ORDER = 0;
`endif
`ifdef FIXED
  localparam bit FIXED_MODE = 1;
`else
  localparam bit FIXED_MODE = 0;
`endif
  bit clk = 0;
  bit zeroize = 0;
  int unsigned vld_coeff_ctr = 0;
  int expected_results[$];
  int errors = 0;

  initial expected_results.push_back(1);

`ifndef FIXED
`ifdef REVERSE
  initial forever begin
    @(posedge clk);
    if (vld_coeff_ctr == 1) begin
      $display("THRESHOLD ctr=%0d t=%0t", vld_coeff_ctr, $time);
      zeroize <= 1;
      @(posedge clk);
      zeroize <= 0;
    end
  end
`endif
  initial forever begin
    @(posedge clk);
    if (!zeroize) begin
      if (expected_results.size() == 0) begin
        $display("QUEUE_UNDERFLOW ctr=%0d t=%0t", vld_coeff_ctr, $time);
        errors++;
      end else begin
        vld_coeff_ctr += 1;
        expected_results.pop_front();
        $display("SCORE ctr=%0d q=%0d t=%0t", vld_coeff_ctr,
                 expected_results.size(), $time);
      end
    end
  end
`ifndef REVERSE
  initial forever begin
    @(posedge clk);
    if (vld_coeff_ctr == 1) begin
      $display("THRESHOLD ctr=%0d t=%0t", vld_coeff_ctr, $time);
      zeroize <= 1;
      @(posedge clk);
      zeroize <= 0;
    end
  end
`endif
`else
`ifdef REVERSE
  initial forever begin
    @(posedge zeroize);
    @(posedge clk);
    zeroize <= 0;
    $display("PULSE_LOW t=%0t", $time);
  end
`endif
  initial forever begin
    @(posedge clk);
    if (!zeroize) begin
      if (expected_results.size() == 0) begin
        $display("QUEUE_UNDERFLOW ctr=%0d t=%0t", vld_coeff_ctr, $time);
        errors++;
      end else begin
        vld_coeff_ctr += 1;
        expected_results.pop_front();
        $display("SCORE ctr=%0d q=%0d t=%0t", vld_coeff_ctr,
                 expected_results.size(), $time);
        if (vld_coeff_ctr == 1) begin
          $display("FIXED_THRESHOLD ctr=%0d t=%0t", vld_coeff_ctr, $time);
          zeroize <= 1;
        end
      end
    end
  end
`ifndef REVERSE
  initial forever begin
    @(posedge zeroize);
    @(posedge clk);
    zeroize <= 0;
    $display("PULSE_LOW t=%0t", $time);
  end
`endif
`endif

  initial forever begin
    @(posedge zeroize);
    $display("CLEAR ctr=%0d q=%0d t=%0t", vld_coeff_ctr,
             expected_results.size(), $time);
    vld_coeff_ctr = '0;
    expected_results = {};
  end

  initial begin
    #1;
    repeat (2) @(posedge clk);
    #1;
`ifdef FIXED
    $display("RESULT fixed=%0d reverse=%0d errors=%0d ctr=%0d q=%0d",
             FIXED_MODE, REVERSE_ORDER, errors, vld_coeff_ctr,
             expected_results.size());
`else
    $display("RESULT reverse=%0d errors=%0d ctr=%0d q=%0d",
             REVERSE_ORDER, errors, vld_coeff_ctr, expected_results.size());
`endif
    $finish;
  end

  always #5 clk = ~clk;
endmodule
