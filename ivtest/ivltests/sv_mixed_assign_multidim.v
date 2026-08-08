// A constant select in a multidimensional packed variable has a canonical
// flattened bit range. The continuous driver owns element 0 ([6:0]); the
// procedural slice owns elements 3:1 ([27:7]). They are disjoint terms under
// IEEE 1800-2017 6.5/11.5.3 and must not be rejected as overlapping drivers.
module sv_mixed_assign_multidim;
  logic [3:0][6:0] m;
  logic failed = 0;

  assign m[0] = 7'h12;

  initial begin
    m[3:1] = {7'h45, 7'h34, 7'h23};
    #0;
    if (m[0] !== 7'h12 || m[1] !== 7'h23 ||
        m[2] !== 7'h34 || m[3] !== 7'h45)
      failed = 1;
    if (failed) $display("FAILED m=%h", m);
    else $display("PASSED");
  end
endmodule

// Pin the parameter-folded nonblocking shape used by Adams Bridge ntt_ctrl.
module caliptra_shape;
  parameter int SRAM_LATENCY = 1;
  logic clk;
  logic [SRAM_LATENCY+1:0][6:0] pipe;

  assign pipe[0] = '0;
  always_ff @(posedge clk)
    pipe[SRAM_LATENCY+1:1] <= '0;
endmodule
