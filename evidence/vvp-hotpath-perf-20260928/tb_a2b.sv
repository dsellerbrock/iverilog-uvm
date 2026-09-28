// Disposable Adams Bridge A2B reducer: N instances of the pinned
// abr_masked_A2B_conv (WIDTH=46), LFSR stimulus, per-instance output hash.
module tb_a2b;
  localparam W = 46;
  localparam N = 4;
  logic clk = 0, rst_n = 1, zeroize = 0;
  integer cyc = 0;
  function automatic logic [63:0] step(input logic [63:0] v);
    return {v[62:0], v[63]^v[62]^v[60]^v[59]};
  endfunction
  genvar g;
  for (g = 0; g < N; g++) begin : u
    logic [1:0] x [W-1:0];
    logic [1:0] s [W-1:0];
    logic [W-1:0] rnd, rb0, rb1;
    logic [63:0] lfsr = 64'h1234_5678_9abc_def1 ^ (64'(g) << 17);
    logic [63:0] hash = 0;
    abr_masked_A2B_conv #(.WIDTH(W)) dut(.clk(clk), .rst_n(rst_n), .zeroize(zeroize),
      .x(x), .rnd(rnd), .rnd_for_Boolean0(rb0), .rnd_for_Boolean1(rb1), .s(s));
    always @(posedge clk)
      if (cyc >= 100)
        for (int k = 0; k < W; k++) hash = {hash[62:0], hash[63]} ^ {62'd0, s[k]};
    always @(negedge clk) begin
      for (int k = 0; k < W; k++) begin lfsr = step(lfsr); x[k] = lfsr[1:0]; end
      lfsr = step(lfsr); rnd = lfsr[W-1:0];
      lfsr = step(lfsr); rb0 = lfsr[W-1:0];
      lfsr = step(lfsr); rb1 = lfsr[W-1:0];
    end
    initial begin
      for (int k = 0; k < W; k++) x[k] = 0;
      rnd = 0; rb0 = 0; rb1 = 0;
    end
  end
  always #5 clk = ~clk;
  always @(posedge clk) cyc <= cyc + 1;
  initial begin
    #1 rst_n = 0;
    #11 rst_n = 1;
    repeat (`CYC) @(posedge clk);
    #1 $display("cycles=%0d hash=%h %h %h %h", cyc, u[0].hash, u[1].hash, u[2].hash, u[3].hash);
    $finish;
  end
endmodule
