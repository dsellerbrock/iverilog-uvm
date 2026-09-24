module sv_queue_fixed_array_concat;
  parameter bit [7:0] READ_CMD_LIST[] = {8'h03, 8'h0b};
  bit [7:0] live[1:2];
  bit [7:0] descending[2:1];
  bit [7:0] q[$];
  bit [7:0] bounded[$:2];

  initial begin
    live[1] = 8'h21;
    live[2] = 8'h22;
    descending[2] = 8'h32;
    descending[1] = 8'h31;

    q = {READ_CMD_LIST};
    if (q.size() != 2 || q[0] != 8'h03 || q[1] != 8'h0b)
      $fatal(1, "constant fixed-array splice");

    q = {8'hf0, live, 8'hf1, descending};
    if (q.size() != 6 || q[0] != 8'hf0 || q[1] != 8'h21
        || q[2] != 8'h22 || q[3] != 8'hf1
        || q[4] != 8'h32 || q[5] != 8'h31)
      $fatal(1, "mixed scalar/live/descending splice");

    q = {q, 8'haa};
    if (q.size() != 7 || q[0] != 8'hf0 || q[5] != 8'h31
        || q[6] != 8'haa)
      $fatal(1, "self-reference snapshot");

    q = {};
    if (q.size() != 0) $fatal(1, "empty queue concatenation");

    bounded = {READ_CMD_LIST, 8'h99};
    if (bounded.size() != 3 || bounded[0] != 8'h03
        || bounded[1] != 8'h0b || bounded[2] != 8'h99)
      $fatal(1, "bounded queue exact capacity");
    $display("PASS fixed-array queue concatenation");
    $finish(0);
  end
endmodule
