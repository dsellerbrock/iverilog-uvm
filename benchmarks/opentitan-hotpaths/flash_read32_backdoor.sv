module top;
  import uvm_pkg::*;

  // OpenTitan Flash stores 64 data bits plus 12 ECC bits per VPI word.
  logic [75:0] mem [0:15];
  logic [31:0] addr, expected, actual;
  bit reference_mode;
  integer pass, i, byte_idx;

  class flash_bkdr_probe;
    int unsigned uvm_hdl_read_calls;

    function uvm_hdl_data_t read_raw(bit [31:0] addr);
      uvm_hdl_data_t raw;
      string path = $sformatf("top.mem[%0d]", addr >> 3);
      uvm_hdl_read_calls++;
      if (!uvm_hdl_read(path, raw))
        $fatal(1, "uvm_hdl_read failed for %s", path);
      return raw;
    endfunction

    function logic [7:0] read8_ref(bit [31:0] addr);
      uvm_hdl_data_t raw = read_raw(addr);
      return (raw >> ((addr % 8) * 8)) & 8'hff;
    endfunction

    function logic [31:0] read32_ref(bit [31:0] addr);
      if (addr % 4)
        $fatal(1, "read32 address is not aligned: %0d", addr);
      return {read8_ref(addr + 3), read8_ref(addr + 2),
              read8_ref(addr + 1), read8_ref(addr)};
    endfunction

    // Mirrors the Flash-only fast path: one raw read covers these four bytes.
    function logic [31:0] read32_once(bit [31:0] addr);
      uvm_hdl_data_t raw;
      int unsigned offset;
      if (addr % 4)
        $fatal(1, "read32 address is not aligned: %0d", addr);
      offset = addr % 8;
      if (offset + 4 > 8)
        return read32_ref(addr);
      raw = read_raw(addr);
      return raw >> (offset * 8);
    endfunction
  endclass

  flash_bkdr_probe probe;

  initial begin
    probe = new;
    reference_mode = $test$plusargs("reference");

    for (i = 0; i < 16; i++) begin
      for (byte_idx = 0; byte_idx < 8; byte_idx++)
        mem[i][byte_idx * 8 +: 8] = (i * 17 + byte_idx * 31) & 8'hff;
      mem[i][75:64] = 12'hxxx;
    end
    mem[3][23:16] = 'x;

    // Both aligned dwords in every word, repeated to expose lookup cost.
    for (pass = 0; pass < 1024; pass++) begin
      for (i = 0; i < 32; i++) begin
        addr = i * 4;
        expected = mem[addr >> 3] >> ((addr % 8) * 8);
        if (reference_mode)
          actual = probe.read32_ref(addr);
        else
          actual = probe.read32_once(addr);
        if (actual !== expected)
          $fatal(1, "bad read32 at %0d: got %h expected %h", addr, actual, expected);
      end
    end

    if (reference_mode)
      $display("PASS flash_read32 mode=reference words=%0d read32_calls=%0d uvm_hdl_read_calls=%0d",
               16, pass * 32, probe.uvm_hdl_read_calls);
    else
      $display("PASS flash_read32 mode=one-read words=%0d read32_calls=%0d uvm_hdl_read_calls=%0d",
               16, pass * 32, probe.uvm_hdl_read_calls);
    $finish;
  end
endmodule
