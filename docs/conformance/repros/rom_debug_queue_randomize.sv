typedef struct packed {
  logic [31:0] start_addr;
  logic [31:0] end_addr;
} addr_range_t;

module top;
  logic [31:0] test_addrs[$];
  addr_range_t sram_main = '{start_addr:32'h10000000, end_addr:32'h10000fff};
  addr_range_t sram_ret = '{start_addr:32'h40600000, end_addr:32'h40600fff};
  logic [31:0] main_lo, main_hi, ret_lo, ret_hi;
  initial begin
    main_lo = sram_main.start_addr;
    main_hi = sram_main.end_addr;
    ret_lo = sram_ret.start_addr;
    ret_hi = sram_ret.end_addr;
`ifdef SIMPLE_SIZE
    if (!std::randomize(test_addrs) with {
      test_addrs.size() inside {[5:20]};
    }) $fatal(1, "randomize failed");
`elsif SIMPLE_FOREACH
    if (!std::randomize(test_addrs) with {
      test_addrs.size() inside {[5:20]};
      foreach (test_addrs[i]) test_addrs[i][1:0] == 0;
    }) $fatal(1, "randomize failed");
`elsif LOCAL_BOUNDS
    if (!std::randomize(test_addrs) with {
      test_addrs.size() inside {[5:20]};
      foreach (test_addrs[i]) {
        test_addrs[i] inside {[main_lo:main_hi]} ||
        test_addrs[i] inside {[ret_lo:ret_hi]};
        test_addrs[i][1:0] == '0;
      }
    }) $fatal(1, "randomize failed");
`else
    if (!std::randomize(test_addrs) with {
      test_addrs.size() inside {[5:20]};
      foreach (test_addrs[i]) {
        test_addrs[i] inside {[sram_main.start_addr:sram_main.end_addr]} ||
        test_addrs[i] inside {[sram_ret.start_addr:sram_ret.end_addr]};
        test_addrs[i][1:0] == '0;
      }
    }) $fatal(1, "randomize failed");
`endif
    if (test_addrs.size() < 5 || test_addrs.size() > 20) $fatal(1, "bad size");
    foreach (test_addrs[i]) begin
      if (!(((test_addrs[i] >= main_lo) && (test_addrs[i] <= main_hi)) ||
            ((test_addrs[i] >= ret_lo) && (test_addrs[i] <= ret_hi)))) $fatal(1, "bad address");
      if (test_addrs[i][1:0] != 0) $fatal(1, "bad alignment");
    end
    $display("PASS size=%0d", test_addrs.size());
  end
endmodule
