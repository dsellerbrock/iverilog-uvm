typedef struct packed {
  logic [31:0] start_addr;
  logic [31:0] end_addr;
} addr_range_t;

module top;
  addr_range_t sram_main = '{start_addr:32'h10000000, end_addr:32'h10000fff};
  addr_range_t sram_ret = '{start_addr:32'h40600000, end_addr:32'h40600fff};
  logic [31:0] main_lo, main_hi, ret_lo, ret_hi;
  logic [31:0] addr;
  int unsigned count;
  logic [31:0] test_addrs[$];
  initial begin
    main_lo = sram_main.start_addr;
    main_hi = sram_main.end_addr;
    ret_lo = sram_ret.start_addr;
    ret_hi = sram_ret.end_addr;
    if (!std::randomize(count) with { count inside {[5:20]}; })
      $fatal(1, "count randomize failed");
    repeat (count) begin
`ifdef STRUCT_BOUNDS
      if (!std::randomize(addr) with {
        (addr inside {[sram_main.start_addr:sram_main.end_addr]}) ||
        (addr inside {[sram_ret.start_addr:sram_ret.end_addr]});
        addr[1:0] == 0;
      }) $fatal(1, "address randomize failed");
`else
      if (!std::randomize(addr) with {
        (addr inside {[main_lo:main_hi]}) ||
        (addr inside {[ret_lo:ret_hi]});
        addr[1:0] == 0;
      }) $fatal(1, "address randomize failed");
`endif
      test_addrs.push_back(addr);
    end
    if (test_addrs.size() < 5 || test_addrs.size() > 20) $fatal(1, "bad size");
    foreach (test_addrs[i]) begin
      if (!(((test_addrs[i] >= main_lo) && (test_addrs[i] <= main_hi)) ||
            ((test_addrs[i] >= ret_lo) && (test_addrs[i] <= ret_hi)))) $fatal(1, "bad address");
      if (test_addrs[i][1:0] != 0) $fatal(1, "bad alignment");
    end
    $display("PASS size=%0d first=%h", test_addrs.size(), test_addrs[0]);
  end
endmodule
