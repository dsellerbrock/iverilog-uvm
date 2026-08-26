// IEEE 1800-2017 35.5.6.1 / Annex H fixed-array DPI ABI.
//
// This is the exact argument shape used by OpenTitan's SHA-384 model: an
// open packed-byte input, a 64-bit length, and a fixed 12-word output. The
// queue actual deliberately has no whole-array C layout, while each byte is
// available through the canonical open-array element interface. The digest
// must use the direct uint32_t[12] ABI and copy every word back to SV.
module m10_dpi_opentitan_sha384_abi_test;
  import "DPI-C" context function void c_dpi_SHA384_hash(
      input bit [7:0] msg[],
      input longint unsigned len,
      output int unsigned hash[12]);

  bit [7:0] msg[$];
  int unsigned hash[12];
  longint unsigned len;
  int errors = 0;

  initial begin
    msg.push_back(8'h4f);
    msg.push_back(8'h70);
    msg.push_back(8'h65);
    msg.push_back(8'h6e);
    msg.push_back(8'h54);
    msg.push_back(8'h69);

    // A nonzero high word proves that longint remains uint64_t in the mixed
    // handle/integer/pointer call signature. The low word is the byte count.
    len = 64'h0000_0001_0000_0006;
    foreach (hash[i]) hash[i] = 32'hdead_beef;

    c_dpi_SHA384_hash(msg, len, hash);

    foreach (hash[i]) begin
      int unsigned expected;
      expected = 32'h3840_005a + i * 32'h0001_0203;
      if (hash[i] !== expected) begin
        $display("FAIL SHA384 ABI hash[%0d]=%08h expected=%08h",
                 i, hash[i], expected);
        errors++;
      end
    end

    if (errors == 0)
      $display("PASS m10_dpi_opentitan_sha384_abi_test");
    $finish;
  end
endmodule
