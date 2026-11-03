module issue2384_struct_to_byte_queue;
  typedef struct {
    byte length;
    shortint address;
    byte payload[];
    byte chksum;
  } Packet;
  typedef byte q_t[$];

  Packet pk;
  q_t ch;

  initial begin
    pk.length = 2;
    pk.address = 16'h1234;
    pk.payload = '{8'hAA, 8'hBB};
    pk.chksum = 8'h11;

    ch = q_t'(pk);
    if (ch.size() != 6
        || ch[0] !== 8'h02
        || ch[1] !== 8'h12
        || ch[2] !== 8'h34
        || ch[3] !== 8'hAA
        || ch[4] !== 8'hBB
        || ch[5] !== 8'h11)
      $fatal(1, "struct-to-queue bit-stream cast mismatch");

    $display("PASSED");
  end
endmodule
