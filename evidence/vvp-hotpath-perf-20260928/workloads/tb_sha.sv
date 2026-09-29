`timescale 1ns/1ps
// Datapath RTL workload: chain NBLK SHA-512 and SHA-256 blocks through the
// unmodified Caliptra v2.1.2 secworks cores; print a digest checksum.
module tb_sha;
  logic clk = 0, rst_n = 0;
  always #5 clk = ~clk;

  logic s5_init = 0, s5_next = 0;
  logic [1023:0] s5_blk = '0;
  logic s5_ready, s5_valid;
  logic [511:0] s5_digest;
  sha512_core u512(.clk(clk), .reset_n(rst_n), .zeroize(1'b0),
    .init_cmd(s5_init), .next_cmd(s5_next), .restore_cmd(1'b0), .mode(2'd3),
    .block_msg(s5_blk), .restore_digest(512'd0),
    .ready(s5_ready), .digest(s5_digest), .digest_valid(s5_valid));

  logic s2_init = 0, s2_next = 0;
  logic [511:0] s2_blk = '0;
  logic s2_ready, s2_valid;
  logic [255:0] s2_digest;
  sha256_core u256(.clk(clk), .reset_n(rst_n), .zeroize(1'b0),
    .init_cmd(s2_init), .next_cmd(s2_next), .mode(1'b1),
    .block_msg(s2_blk), .ready(s2_ready), .digest(s2_digest),
    .digest_valid(s2_valid));

  logic [63:0] sum = 0;
  initial begin
    #22 rst_n = 1;
    fork
      begin : s512
        for (int n = 0; n < `NBLK; n++) begin
          @(posedge clk);
          s5_blk <= {s5_digest, s5_digest ^ {8{64'(n)}}};
          if (n == 0) s5_init <= 1; else s5_next <= 1;
          @(posedge clk); s5_init <= 0; s5_next <= 0;
          @(posedge clk); wait (s5_ready);
        end
      end
      begin : s256
        for (int n = 0; n < 2 * `NBLK; n++) begin
          @(posedge clk);
          s2_blk <= {s2_digest, s2_digest ^ {8{32'(n)}}};
          if (n == 0) s2_init <= 1; else s2_next <= 1;
          @(posedge clk); s2_init <= 0; s2_next <= 0;
          @(posedge clk); wait (s2_ready);
        end
      end
    join
    for (int k = 0; k < 8; k++) sum ^= s5_digest[k*64 +: 64];
    for (int k = 0; k < 4; k++) sum ^= {32'd0, s2_digest[k*64 +: 32]} ^ {s2_digest[k*64+32 +: 32], 32'd0};
    $display("NBLK=%0d sha512=%h sha256=%h sum=%h", `NBLK, s5_digest[511:448], s2_digest[255:224], sum);
    $finish;
  end
endmodule
