// IEEE 1800-2017/2023 6.24.3: a string is a dynamic array of bytes for
// bit-stream casts, so a byte queue converts to the corresponding string.
module sv_bitstream_queue_to_string;
  byte dq[$];
  string str;

  initial begin
    dq.push_back("A");
    dq.push_back("B");
    str = string'(dq);
    if (str != "AB") begin
      $display("FAILED: byte queue cast produced <%s>", str);
      $fatal(1);
    end
    $display("PASSED");
  end
endmodule
