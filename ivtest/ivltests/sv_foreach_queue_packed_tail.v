// IEEE 1800-2017/2023 12.7.3: foreach visits the queue and packed dimensions,
// preserving the ascending packed bounds and traversal order.
module top;
  bit [0:1] q[$];
  int seen[1:0][0:1];
  int visits;

  initial begin
    q.push_back(2'b10);
    q.push_back(2'b01);

    foreach (q[i, bit_index]) begin
      if (i < 0 || i > 1 || bit_index < 0 || bit_index > 1)
        $fatal(1, "foreach index out of bounds: %0d,%0d", i, bit_index);
      if (i != visits / 2 || bit_index != visits % 2)
        $fatal(1, "wrong foreach order at visit %0d: %0d,%0d",
               visits, i, bit_index);
      if (q[i][bit_index] !== ((i == 0 && bit_index == 0)
                               || (i == 1 && bit_index == 1)))
        $fatal(1, "wrong packed queue bit at %0d,%0d", i, bit_index);
      seen[i][bit_index]++;
      visits++;
    end

    if (visits != 4 || seen[0][1] != 1 || seen[0][0] != 1
        || seen[1][1] != 1 || seen[1][0] != 1)
      $fatal(1, "wrong queue/packed visits: %0d", visits);
    $display("PASSED");
  end
endmodule
