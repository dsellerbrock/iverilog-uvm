module issue2385_string_to_byte_queue;
  typedef byte byte_queue_t[$];

  byte_queue_t bytes;
  string text = "AB";

  initial begin
    bytes = byte_queue_t'(text);
    if (bytes.size() != 2 || bytes[0] != 8'd65 || bytes[1] != 8'd66)
      $fatal(1, "string-to-queue cast: size=%0d bytes=%0d,%0d",
             bytes.size(), bytes[0], bytes[1]);
    $display("PASSED");
  end
endmodule
