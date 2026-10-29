module top;
  typedef int int_queue_t[$];
  typedef logic [7:0] byte_queue_t[$];

  int values [int];
  int signed_values [int];
  int string_values [string];
  logic [7:0] four_state_values [int];
  int_queue_t q;
  byte_queue_t bytes;
  byte_queue_t four_state_bytes;

  initial begin
    values[9] = 90;
    values[2] = 20;
    values[5] = 50;
    q = int_queue_t'(values);
    if (q.size() != 3 || q[0] != 20 || q[1] != 50 || q[2] != 90)
      $fatal(1, "associative key-sorted bit stream");

    signed_values[9] = 90;
    signed_values[-1] = 10;
    signed_values[2] = 20;
    q = int_queue_t'(signed_values);
    if (q.size() != 3 || q[0] != 10 || q[1] != 20 || q[2] != 90)
      $fatal(1, "signed associative key order");

    string_values["z"] = 90;
    string_values["a"] = 20;
    string_values["m"] = 50;
    q = int_queue_t'(string_values);
    if (q.size() != 3 || q[0] != 20 || q[1] != 50 || q[2] != 90)
      $fatal(1, "string associative key order");

    bytes = byte_queue_t'(values);
    if (bytes.size() != 12 || bytes[0] !== 8'h00
        || bytes[1] !== 8'h00 || bytes[2] !== 8'h00
        || bytes[3] !== 8'h14 || bytes[4] !== 8'h00
        || bytes[5] !== 8'h00 || bytes[6] !== 8'h00
        || bytes[7] !== 8'h32 || bytes[8] !== 8'h00
        || bytes[9] !== 8'h00 || bytes[10] !== 8'h00
        || bytes[11] !== 8'h5a)
      $fatal(1, "associative stream repartitioning");

    four_state_values[2] = 8'hx5;
    four_state_values[1] = 8'hzA;
    four_state_bytes = byte_queue_t'(four_state_values);
    if (four_state_bytes.size() != 2 || four_state_bytes[0] !== 8'hzA
        || four_state_bytes[1] !== 8'hx5)
      $fatal(1, "associative four-state bit stream");

    $display("PASS associative bit-stream casts to queues");
    $display("PASSED");
  end
endmodule
