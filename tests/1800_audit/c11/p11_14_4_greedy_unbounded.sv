module p11_14_4_greedy_unbounded;
  byte packet_bytes[];
  byte unused_bytes[];
  byte final_byte;
  byte all_bytes[];
  logic [31:0] packet = 32'h1122_3344;
  logic [31:0] whole_packet = 32'h5566_7788;

  initial begin
    {>>{packet_bytes, unused_bytes, final_byte}} = packet;
    if (packet_bytes.size() != 3 || unused_bytes.size() != 0 ||
        packet_bytes[0] !== 8'h11 || packet_bytes[1] !== 8'h22 ||
        packet_bytes[2] !== 8'h33 || final_byte !== 8'h44)
      $fatal(1, "greedy stream unpack mismatch");

    {>>{all_bytes}} = whole_packet;
    if (all_bytes.size() != 4 || all_bytes[0] !== 8'h55 ||
        all_bytes[1] !== 8'h66 || all_bytes[2] !== 8'h77 ||
        all_bytes[3] !== 8'h88)
      $fatal(1, "single dynamic stream item did not consume full stream");

    $display("PASS: greedy unbounded streaming unpack");
  end
endmodule
