module test;
  byte stream[$];
  initial begin
    if ($bits(stream) != 0) $fatal(1, "$bits(empty queue) must be zero");
    repeat (8) stream.push_back(8'h5a);
    if ($bits(stream) != 64) $fatal(1, "$bits(eight bytes) must be 64");
    $display("bits_empty=0 bits_8_bytes=64");
    $display("PASSED");
  end
endmodule
