typedef int int_queue_t[$];

module issue1455_assoc_bitstream_cast;
  int values [int];
  int_queue_t q;

  initial begin
    values[9] = 90;
    values[2] = 20;
    values[-3] = -30;
    values[5] = 50;
    q = int_queue_t'(values);
    if (q.size() != 4 || q[0] != -30 || q[1] != 20
        || q[2] != 50 || q[3] != 90)
      $fatal(1, "associative bit-stream key order");
    $display("PASS associative key-sorted bit stream");
  end
endmodule
