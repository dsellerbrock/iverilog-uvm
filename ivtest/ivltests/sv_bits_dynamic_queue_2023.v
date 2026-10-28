class bits_queue_owner;
  byte items[$];
endclass

typedef struct {
  byte data[2];
  bit valid;
} packet_t;

module main;
  byte bytes[$];
  byte removed;
  bit [15:0] words[$];
  byte bounded[$:3];
  packet_t packets[$];
  packet_t packet;
  bits_queue_owner owner;

  initial begin
    if ($bits(bytes) != 0)
      $fatal(1, "empty byte queue: expected 0 bits, got %0d", $bits(bytes));

    bytes.push_back(8'h11);
    if ($bits(bytes) != 8)
      $fatal(1, "one byte: expected 8 bits, got %0d", $bits(bytes));
    repeat (7) bytes.push_back(8'h22);
    if ($bits(bytes) != 64)
      $fatal(1, "eight bytes: expected 64 bits, got %0d", $bits(bytes));
    removed = bytes.pop_back();
    if (removed != 8'h22)
      $fatal(1, "pop_back: expected 8'h22, got %0h", removed);
    if ($bits(bytes) != 56)
      $fatal(1, "pop_back: expected 56 bits, got %0d", $bits(bytes));
    bytes.delete();
    if ($bits(bytes) != 0)
      $fatal(1, "deleted byte queue: expected 0 bits, got %0d", $bits(bytes));

    words.push_back(16'h1234);
    words.push_back(16'habcd);
    if ($bits(words) != 32)
      $fatal(1, "two 16-bit words: expected 32 bits, got %0d", $bits(words));

    packet.data[0] = 8'h12;
    packet.data[1] = 8'h34;
    packet.valid = 1'b0;
    packets.push_back(packet);
    packet.data[0] = 8'h56;
    packet.data[1] = 8'h78;
    packet.valid = 1'b1;
    packets.push_back(packet);
    if ($bits(packets) != 34)
      $fatal(1, "two fixed unpacked records: expected 34 bits, got %0d", $bits(packets));

    bounded.push_back(8'h5a);
    bounded.push_back(8'ha5);
    if ($bits(bounded) != 16)
      $fatal(1, "bounded queue: expected 16 bits, got %0d", $bits(bounded));

    owner = new;
    if ($bits(owner.items) != 0)
      $fatal(1, "empty class queue: expected 0 bits, got %0d", $bits(owner.items));
    owner.items.push_back(8'h7e);
    owner.items.push_back(8'h81);
    if ($bits(owner.items) != 16)
      $fatal(1, "class queue: expected 16 bits, got %0d", $bits(owner.items));

    $display("PASSED");
    $finish(0);
  end
endmodule
