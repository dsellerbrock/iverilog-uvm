module top;
  bit [31:0] value;
  int unsigned counts[0:7];
  int unsigned seed = 20261004;
  int unsigned i;

  initial begin
    automatic process self_p = process::self();
    for (i = 0; i < 8; i++) counts[i] = 0;
    i = 0;
    self_p.srandom(seed);
    for (i = 0; i < 64; i++) begin
      if (!std::randomize(value) with {
            value inside {
              32'h00000001, 32'h00010003, 32'h01000007, 32'h1000000b,
              32'h8000000d, 32'h80010011, 32'hfeed0001, 32'hffffffff
            };
          })
        $fatal(1, "sparse randomize failed at draw %0d", i);
      case (value)
        32'h00000001: counts[0]++;
        32'h00010003: counts[1]++;
        32'h01000007: counts[2]++;
        32'h1000000b: counts[3]++;
        32'h8000000d: counts[4]++;
        32'h80010011: counts[5]++;
        32'hfeed0001: counts[6]++;
        32'hffffffff: counts[7]++;
        default: $fatal(1, "value outside sparse support: %08x", value);
      endcase
    end
    $display("PASS vvp_sparse_randomize seed=%0d draws=%0d bins={%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d}",
             seed, i, counts[0], counts[1], counts[2], counts[3],
             counts[4], counts[5], counts[6], counts[7]);
    $finish;
  end
endmodule
