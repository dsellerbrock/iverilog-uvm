class rom_util;
  function int unsigned get_size_bytes();
    return 1024;
  endfunction
  function int unsigned get_bytes_per_word();
    return 4;
  endfunction
endclass

module top;
  rom_util util;
  bit [31:0] addr;
  int unsigned rom_bytes;
  int unsigned word_bytes;
  initial begin
    util = new;
`ifdef CACHE
    rom_bytes = util.get_size_bytes();
    word_bytes = util.get_bytes_per_word();
    if (!std::randomize(addr) with {
      addr inside {[rom_bytes-32:rom_bytes-1]};
      (addr % word_bytes) == 0;
    }) $fatal(1, "randomize failed");
`else
    if (!std::randomize(addr) with {
      addr inside {[util.get_size_bytes()-32:util.get_size_bytes()-1]};
      (addr % util.get_bytes_per_word()) == 0;
    }) $fatal(1, "randomize failed");
`endif
    if (addr < 992 || addr > 1023 || addr % 4 != 0) $fatal(1, "bad address");
    $display("PASS addr=%0d", addr);
  end
endmodule
